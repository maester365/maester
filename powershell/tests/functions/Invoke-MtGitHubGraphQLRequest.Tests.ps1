BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'GitHub GraphQL read transport' {
    BeforeEach {
        $script:gqlBody = '{"data":{"viewer":{"login":"fixture-user"}}}'
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; Organization = 'fixture-org'; ApiBaseUri = 'https://api.github.com'; ApiVersion = '2022-11-28' }
            $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer synthetic'; 'X-GitHub-Api-Version' = '2022-11-28' }
            $__MtSession.GitHubCache = @{}
            $__MtSession.MaesterConfig = [pscustomobject]@{ GlobalSettings = [pscustomobject]@{} }
        }
        Mock Invoke-WebRequest -ModuleName Maester { [pscustomobject]@{ Content = $script:gqlBody; Headers = @{} } }
    }
    AfterEach {
        InModuleScope Maester { $__MtSession.GitHubConnection = $null; $__MtSession.GitHubAuthHeader = $null; $__MtSession.GitHubCache = @{}; $__MtSession.MaesterConfig = $null }
    }
    It 'Posts a query with variables and does not apply REST version headers' {
        InModuleScope Maester { Invoke-MtGitHubGraphQLRequest -Query 'query Fixture($id:String!){viewer{login}}' -Variables @{ id = 'fixture' } -OperationName Fixture | Out-Null }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
            $Uri -eq 'https://api.github.com/graphql' -and $Method -eq 'POST' -and
            -not $Headers.ContainsKey('X-GitHub-Api-Version') -and ($Body | ConvertFrom-Json).variables.id -eq 'fixture'
        }
        InModuleScope Maester { $__MtSession.GitHubAuthHeader['X-GitHub-Api-Version'] } | Should -Be '2022-11-28'
    }
    It 'Isolates query text, variables, cursor and operation name' {
        InModuleScope Maester {
            Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{ slug = 'one'; after = $null } -OperationName Fixture | Out-Null
            Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{ slug = 'one'; after = $null } -OperationName Fixture | Out-Null
            Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{ slug = 'two'; after = $null } -OperationName Fixture | Out-Null
            Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{ slug = 'two'; after = 'next' } -OperationName Fixture | Out-Null
            Invoke-MtGitHubGraphQLRequest -Query 'query Other{viewer{login}}' -Variables @{ slug = 'two'; after = 'next' } -OperationName Other | Out-Null
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 4
    }
    It 'Bounds requests and does not cache or retry a timeout' {
        Mock Invoke-WebRequest -ModuleName Maester { throw [System.TimeoutException]::new('Synthetic stalled request.') }
        InModuleScope Maester {
            { Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture } | Should -Throw '*stalled request*'
            $__MtSession.GitHubCache.Count | Should -Be 0
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
            $ConnectionTimeoutSeconds -eq 30 -and $OperationTimeoutSeconds -eq 30
        }
    }
    It 'Routes to the connected GHE.com host and isolates its cache' {
        InModuleScope Maester {
            Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture | Out-Null
            $__MtSession.GitHubConnection.ApiBaseUri = 'https://api.fixture.ghe.com'
            Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture | Out-Null
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter { $Uri -eq 'https://api.fixture.ghe.com/graphql' }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
    }
    It 'Retains original times and refreshes expired evidence' {
        InModuleScope Maester {
            $first = Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture
            $hit = Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture
            $hit.StartedUtc | Should -Be $first.StartedUtc
            $hit.CompletedUtc | Should -Be $first.CompletedUtc
            $first.CompletedUtc = [DateTimeOffset]::UtcNow.AddMinutes(-6)
            $fresh = Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture
            $fresh.CompletedUtc | Should -BeGreaterThan $first.CompletedUtc
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
    }
    It 'Does not cache known field-access errors with partial data' {
        $script:gqlBody = '{"data":{"enterprise":{"ownerInfo":null}},"errors":[{"type":"FORBIDDEN","path":["enterprise","ownerInfo"]}]}'
        $out = InModuleScope Maester {
            $result = Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{enterprise(slug:"fixture"){ownerInfo{notificationDeliveryRestrictionEnabledSetting}}}' -Variables @{} -OperationName Fixture
            $__MtSession.GitHubCache.Count | Should -Be 0
            $result
        }
        $out.Errors | Should -Contain 'FORBIDDEN'
    }
    It 'Does not cache defensive malformed root shapes <Body>' -ForEach @(
        @{ Body = '[]' }, @{ Body = '[{"data":{}}]' }, @{ Body = 'null' }, @{ Body = '{"data":null}' }
    ) {
        $script:gqlBody = $Body
        InModuleScope Maester {
            Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture | Out-Null
            $__MtSession.GitHubCache.Count | Should -Be 0
        }
    }
    It 'Throws for unexpected GraphQL errors including throttling' {
        $script:gqlBody = '{"errors":[{"type":"RATE_LIMITED","message":"synthetic"}],"data":null}'
        { InModuleScope Maester { Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture } } | Should -Throw '*execution failed*'
    }
    It 'Throws for invalid JSON' {
        $script:gqlBody = '{bad'
        { InModuleScope Maester { Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture } } | Should -Throw
    }
    It 'Rejects mutation and disconnected use before transport' {
        { InModuleScope Maester { Invoke-MtGitHubGraphQLRequest -Query 'mutation Fixture{noop}' -Variables @{} -OperationName Fixture } } | Should -Throw '*read queries*'
        InModuleScope Maester { $__MtSession.GitHubConnection = $null }
        { InModuleScope Maester { Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture } } | Should -Throw '*Connect-MtGitHub*'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 0
    }
    It 'Bypasses cache reads and writes when requested' {
        InModuleScope Maester {
            Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture -DisableCache | Out-Null
            Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture -DisableCache | Out-Null
            $__MtSession.GitHubCache.Count | Should -Be 0
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
    }
    It 'Clears cached evidence through actual disconnect and reconnect paths' {
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/user$' } { [pscustomobject]@{ Content = '{"login":"fixture-user"}'; Headers = @{} } }
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/orgs/fixture-org$' } { [pscustomobject]@{ Content = '{"login":"fixture-org","plan":{"name":"enterprise"}}'; Headers = @{} } }
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/memberships/orgs/' } { [pscustomobject]@{ Content = '{"state":"active","role":"admin"}'; Headers = @{} } }
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/actions/permissions' } { [pscustomobject]@{ Content = '{"enabled_repositories":"all"}'; Headers = @{} } }
        InModuleScope Maester {
            Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture | Out-Null
            Disconnect-MtGitHub
            $__MtSession.GitHubCache.Count | Should -Be 0
            $token = [System.Security.SecureString]::new()
            $token.AppendChar('x')
            Connect-MtGitHub -Organization fixture-org -Token $token -ApiBaseUri https://api.github.com -ApiVersion '2022-11-28'
            $__MtSession.GitHubConnection.Connected | Should -BeTrue
            Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture | Out-Null
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2 -ParameterFilter { $Method -eq 'POST' }
    }
    It 'Does not ignore a defensive malformed errors collection <Errors>' -ForEach @(
        @{Errors='false'},@{Errors='null'},@{Errors='"FORBIDDEN"'},@{Errors='[null]'}
    ) {
        $script:gqlBody='{"data":{"viewer":{"login":"fixture-user"}},"errors":'+$Errors+'}'
        {InModuleScope Maester {Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture}} | Should -Throw '*error collection*'
    }

}
