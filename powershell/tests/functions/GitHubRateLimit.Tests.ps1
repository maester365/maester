BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'GitHub rate limits through transport and native checks' {
    BeforeEach {
        $script:policyCalls = 0
        $script:limitStatus = 429
        $script:limitHeaders = @{ 'retry-after' = '120' }
        $script:limitBody = '{"message":"You have exceeded a secondary rate limit."}'
        $script:successfulPolicies = 0
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; Organization = 'fixture-org'; ApiBaseUri = 'https://api.github.com'; ApiVersion = '2022-11-28' }
            $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer synthetic-no-network' }
            $__MtSession.GitHubCache = @{}
            $__MtSession.MaesterConfig = $null
        }
        Mock Invoke-WebRequest -ModuleName Maester {
            if ($Uri -match '/orgs/fixture-org/repos') {
                return [pscustomobject]@{ Content = '[{"id":101,"name":"repo","full_name":"fixture-org/repo","owner":{"login":"fixture-org"}},{"id":102,"name":"other","full_name":"fixture-org/other","owner":{"login":"fixture-org"}}]'; Headers = @{} }
            }
            if ($Method -eq 'POST') { return [pscustomobject]@{ Content = '{"data":{"viewer":{"login":"fixture-user"}}}'; Headers = @{} } }
            $script:policyCalls++
            if ($script:policyCalls -le $script:successfulPolicies) {
                return [pscustomobject]@{ Content = '{"required_pull_request_reviews":{"dismiss_stale_reviews":true,"require_code_owner_reviews":true}}'; Headers = @{} }
            }
            $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$script:limitStatus)
            foreach ($key in $script:limitHeaders.Keys) { $null = $response.Headers.TryAddWithoutValidation($key, [string]$script:limitHeaders[$key]) }
            $err = [System.Management.Automation.ErrorRecord]::new([Microsoft.PowerShell.Commands.HttpResponseException]::new('Synthetic HTTP failure', $response), 'FixtureHttp', 'InvalidOperation', $null)
            $err.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($script:limitBody)
            throw $err
        }
        $script:scopeConfig = @{ GlobalSettings = @{ GitHubCisRepositoryScope = @{ Organization = 'fixture-org'; Complete = $true; Repositories = @(
                    @{ Id = 101; InUse = $true; MainBranches = @(1..100 | ForEach-Object { "branch-$_" }) }
                    @{ Id = 102; InUse = $true; MainBranches = @('main') }
                ) } } }
    }
    AfterEach {
        InModuleScope Maester { $__MtSession.GitHubConnection = $null; $__MtSession.GitHubAuthHeader = $null; $__MtSession.GitHubCache = @{}; $__MtSession.MaesterConfig = $null }
    }

    It 'Stops traffic across branches, repositories and two native checks for <Kind>' -ForEach @(
        @{ Kind = '429 Retry-After'; Status = 429; Primary = $false }
        @{ Kind = '403 primary exhaustion'; Status = 403; Primary = $true }
    ) {
        $script:limitStatus = $Status
        if ($Primary) { $script:limitHeaders = @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = [DateTimeOffset]::UtcNow.AddMinutes(10).ToUnixTimeSeconds(); 'x-ratelimit-resource' = 'core' }; $script:limitBody = '{"message":"API rate limit exceeded"}' }
        $rows = @(Invoke-MtTest -Id 'CIS.GH.1.1.4', 'CIS.GH.1.1.7' -Config $script:scopeConfig)
        $rows.Count | Should -Be 2
        @($rows | Where-Object Result -NE 'Error').Count | Should -Be 0
        $script:policyCalls | Should -Be 1
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
    }

    It 'Stops native branch-population enumeration and subsequent checks after rate limiting' {
        $rows = @(Invoke-MtTest -Id 'CIS.GH.1.1.12', 'CIS.GH.1.1.4' -Config $script:scopeConfig)
        $rows.Count | Should -Be 2
        @($rows | Where-Object Result -NE 'Error').Count | Should -Be 0
        $script:policyCalls | Should -Be 1
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 0 -ParameterFilter { $Uri -match '/protection' }
    }

    It 'Retains completed branch findings and does not count unvisited branches as evaluated' {
        $script:successfulPolicies = 1
        $row = Invoke-MtTest -Id 'CIS.GH.1.1.4' -Config $script:scopeConfig
        $row.Result | Should -Be 'Error'
        $row.ResultDetail.TestResult | Should -Match 'Passed findings: 1'
        $row.ResultDetail.TestResult | Should -Match 'Evaluated branch findings: 2;'
        $row.ResultDetail.TestResult | Should -Match 'not assessed'
        $script:policyCalls | Should -Be 2
    }

    It 'Preserves structured retry metadata, blocks DisableCache and expires without waiting' {
        InModuleScope Maester {
            $caught = $null
            try { Invoke-MtGitHubRequest '/policy' -IncludeMetadata | Out-Null } catch { $caught = $_ }
            $caught.Exception.Data['GitHubRateLimit'].Kind | Should -Be 'Secondary'
            $caught.Exception.Data['GitHubRateLimit'].RetryAfterSeconds | Should -Be 120
            $caught.Exception.Data['GitHubRateLimit'].ResumeUtc | Should -BeGreaterThan ([DateTimeOffset]::UtcNow.AddSeconds(110))
            { Invoke-MtGitHubRequest '/policy' -DisableCache } | Should -Throw '*rate limit*'
            $__MtSession.GitHubCache.Count | Should -Be 0
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
        InModuleScope Maester {
            foreach ($limit in $__MtSession.GitHubRateLimits.Limits.Values) { $limit.ResumeUtc = [DateTimeOffset]::UtcNow.AddSeconds(-1) }
        }
        $script:successfulPolicies = 100
        InModuleScope Maester { (Invoke-MtGitHubRequest '/policy').required_pull_request_reviews.dismiss_stale_reviews | Should -BeTrue }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
    }

    It 'Keeps ordinary permission 403 separate and continues other objects' {
        $script:limitStatus = 403
        $script:limitHeaders = @{}
        $script:limitBody = '{"message":"Resource not accessible by integration"}'
        $rows = @(Invoke-MtTest -Id 'CIS.GH.1.1.4', 'CIS.GH.1.1.7' -Config $script:scopeConfig)
        @($rows | Where-Object Result -NE 'Error').Count | Should -Be 0
        $script:policyCalls | Should -Be 202
    }

    It 'Shares secondary limits with GraphQL while preserving separate primary quotas' -ForEach @(@{ Primary = $true }, @{ Primary = $false }) {
        if ($Primary) { $script:limitStatus = 403; $script:limitHeaders = @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = [DateTimeOffset]::UtcNow.AddMinutes(10).ToUnixTimeSeconds() }; $script:limitBody = '{"message":"API rate limit exceeded"}' }
        InModuleScope Maester -Parameters @{ Primary = $Primary } {
            { Invoke-MtGitHubRequest '/policy' } | Should -Throw
            if ($Primary) {
                (Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture).Data.viewer.login | Should -Be 'fixture-user'
            } else {
                { Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture -DisableCache } | Should -Throw '*rate limit*'
            }
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times $(if ($Primary) { 2 } else { 1 })
    }

    It 'Scopes cooldowns to the connection and host and preserves them across per-run cache clearing' {
        InModuleScope Maester {
            { Invoke-MtGitHubRequest '/policy' } | Should -Throw
            Clear-ModuleVariable
            { Invoke-MtGitHubRequest '/other-policy' } | Should -Throw '*rate limit*'
            $__MtSession.GitHubConnection.ApiBaseUri = 'https://api.fixture.ghe.com'
        }
        $script:successfulPolicies = 100
        InModuleScope Maester {
            Invoke-MtGitHubRequest '/policy' | Out-Null
            $__MtSession.GitHubConnection.ApiBaseUri = 'https://api.github.com'
            { Invoke-MtGitHubRequest '/policy' } | Should -Throw '*rate limit*'
            $connection = $__MtSession.GitHubConnection
            Disconnect-MtGitHub
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; Organization = 'fixture-org'; ApiBaseUri = $connection.ApiBaseUri; ApiVersion = $connection.ApiVersion }
            $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer other-synthetic' }
            Invoke-MtGitHubRequest '/policy' | Out-Null
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 3
    }
}

Describe 'Rate-limited pagination and successful exhaustion' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; ApiBaseUri = 'https://api.github.com'; ApiVersion = '2022-11-28' }
            $__MtSession.GitHubAuthHeader = @{}
            $__MtSession.GitHubCache = @{}
        }
    }
    AfterEach { InModuleScope Maester { $__MtSession.GitHubConnection = $null; $__MtSession.GitHubAuthHeader = $null; $__MtSession.GitHubCache = @{} } }

    It 'Retains a successful final response with zero remaining and allows cache reads' {
        Mock Invoke-WebRequest -ModuleName Maester { [pscustomobject]@{ Content = '{"id":101}'; Headers = @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = [DateTimeOffset]::UtcNow.AddMinutes(10).ToUnixTimeSeconds() } } }
        InModuleScope Maester {
            (Invoke-MtGitHubRequest '/repository' -IncludeMetadata).Data.id | Should -Be 101
            (Invoke-MtGitHubRequest '/repository' -IncludeMetadata).Data.id | Should -Be 101
            { Invoke-MtGitHubRequest '/next' -DisableCache } | Should -Throw '*rate limit*'
            $__MtSession.GitHubCache.Count | Should -Be 1
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
    }

    It 'Stops before a prohibited next page, retains collected evidence and never caches a partial collection (metadata=<Metadata>)' -ForEach @(@{ Metadata = $true }, @{ Metadata = $false }) {
        Mock Invoke-WebRequest -ModuleName Maester { [pscustomobject]@{ Content = '[{"id":101}]'; Headers = @{ Link = $(if ($Uri -notmatch '[?&]page=') { '<https://api.github.com/repos?page=2>; rel="next"' }); 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = [DateTimeOffset]::UtcNow.AddMinutes(10).ToUnixTimeSeconds() } } }
        InModuleScope Maester -Parameters @{ Metadata = $Metadata } {
            $caught = $null
            try { Invoke-MtGitHubRequest '/repos' -Paginate -IncludeMetadata:$Metadata | Out-Null } catch { $caught = $_ }
            $caught.Exception.Data['GitHubRateLimit'].Kind | Should -Be 'Primary'
            $partial = $caught.Exception.Data['GitHubPartialResponse']
            $partial.Data[0].id | Should -Be 101
            $partial.PaginationComplete | Should -BeFalse
            $partial.PageCount | Should -Be 1
            $__MtSession.GitHubCache.Count | Should -Be 0
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
    }

    It 'Stops on a later-page 429 and retains the earlier page' {
        Mock Invoke-WebRequest -ModuleName Maester {
            if ($Uri -notmatch '[?&]page=') { return [pscustomobject]@{ Content = '[{"id":101}]'; Headers = @{ Link = '<https://api.github.com/repos?page=2>; rel="next"' } } }
            $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
            $null = $response.Headers.TryAddWithoutValidation('retry-after', '120')
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Synthetic rate limit', $response)
        }
        InModuleScope Maester {
            $caught = $null
            try { Invoke-MtGitHubRequest '/repos' -Paginate -IncludeMetadata | Out-Null } catch { $caught = $_ }
            $caught.Exception.Data['GitHubPartialResponse'].Data[0].id | Should -Be 101
            { Invoke-MtGitHubRequest '/other' } | Should -Throw '*rate limit*'
            $__MtSession.GitHubCache.Count | Should -Be 0
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
    }
}


Describe 'GraphQL and bootstrap rate-limit boundaries' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; Organization = 'fixture-org'; ApiBaseUri = 'https://api.github.com'; ApiVersion = '2022-11-28' }
            $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer synthetic' }
            $__MtSession.GitHubCache = @{}
            $__MtSession.MaesterConfig = $null
        }
    }
    AfterEach { InModuleScope Maester { $__MtSession.GitHubConnection = $null; $__MtSession.GitHubAuthHeader = $null; $__MtSession.GitHubCache = @{}; $__MtSession.MaesterConfig = $null } }

    It 'Handles HTTP 200 GraphQL RATE_LIMITED without confusing primary quotas and shared secondary limits (primary=<Primary>)' -ForEach @(@{ Primary = $true }, @{ Primary = $false }) {
        $script:primary = $Primary
        Mock Invoke-WebRequest -ModuleName Maester {
            if ($Method -eq 'GET') { return [pscustomobject]@{ Content = '{"id":101}'; Headers = @{} } }
            $headers = if ($script:primary) { @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = [DateTimeOffset]::UtcNow.AddMinutes(10).ToUnixTimeSeconds(); 'x-ratelimit-resource' = 'graphql' } } else { @{} }
            [pscustomobject]@{ Content = '{"data":null,"errors":[{"type":"RATE_LIMITED","message":"You have exceeded a secondary rate limit."}]}'.Replace('You have exceeded a secondary rate limit.', $(if ($script:primary) { 'API rate limit exceeded' } else { 'You have exceeded a secondary rate limit.' })); Headers = $headers }
        }
        InModuleScope Maester -Parameters @{ Primary = $Primary } {
            $caught = $null
            try { Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture | Out-Null } catch { $caught = $_ }
            $limit = $caught.Exception.Data['GitHubRateLimit']
            $limit.Kind | Should -Be $(if ($Primary) { 'Primary' } else { 'Secondary' })
            $limit.Scope | Should -Be $(if ($Primary) { 'GraphQL' } else { 'All' })
            if ($Primary) { $limit.ResetUtc | Should -BeGreaterThan ([DateTimeOffset]::UtcNow); (Invoke-MtGitHubRequest '/repository').id | Should -Be 101 }
            else { { Invoke-MtGitHubRequest '/repository' } | Should -Throw '*rate limit*' }
            { Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture -DisableCache } | Should -Throw '*rate limit*'
            @($__MtSession.GitHubCache.Keys | Where-Object { $_ -like 'GraphQL|*' }).Count | Should -Be 0
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times $(if ($Primary) { 2 } else { 1 })
    }

    It 'Retains successful GraphQL data at primary exhaustion and stops the next association cursor' {
        Mock Invoke-WebRequest -ModuleName Maester {
            [pscustomobject]@{ Content = '{"data":{"enterprise":{"id":"E_fixture","slug":"fixture-enterprise","organizations":{"nodes":[],"pageInfo":{"hasNextPage":true,"endCursor":"next"}}}}}'; Headers = @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = [DateTimeOffset]::UtcNow.AddMinutes(10).ToUnixTimeSeconds() } }
        }
        InModuleScope Maester {
            $__MtSession.MaesterConfig = [pscustomobject]@{ GlobalSettings = [pscustomobject]@{ GitHubEnterprise = 'fixture-enterprise' } }
            { Test-MtCisGitHubEnterprise -Purpose Association -OrganizationId O_fixture -OrganizationLogin fixture-org } | Should -Throw '*rate limit*'
            $__MtSession.GitHubCache.Count | Should -Be 1
            @($__MtSession.GitHubCache.Values)[0].Data.enterprise.id | Should -Be 'E_fixture'
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
    }

    It 'Shares an HTTP secondary limit received by GraphQL with REST' {
        Mock Invoke-WebRequest -ModuleName Maester {
            $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
            $null = $response.Headers.TryAddWithoutValidation('retry-after', '120')
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Synthetic rate limit', $response)
        }
        InModuleScope Maester {
            { Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture } | Should -Throw '*rate limit*'
            { Invoke-MtGitHubRequest '/repository' -DisableCache } | Should -Throw '*rate limit*'
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
    }

    It 'Preserves bootstrap cooldowns at <Probe> after <Outcome>' -ForEach @(
        @{ Probe = 'user'; Outcome = 'Success'; ExpectedRequests = 1 }
        @{ Probe = 'orgs/fixture-org'; Outcome = 'Success'; ExpectedRequests = 2 }
        @{ Probe = 'user/memberships/orgs/fixture-org'; Outcome = 'Success'; ExpectedRequests = 3 }
        @{ Probe = 'orgs/fixture-org/actions/permissions'; Outcome = 'Success'; ExpectedRequests = 4 }
        @{ Probe = 'user'; Outcome = 'Error'; ExpectedRequests = 1 }
        @{ Probe = 'orgs/fixture-org'; Outcome = 'Error'; ExpectedRequests = 2 }
        @{ Probe = 'user/memberships/orgs/fixture-org'; Outcome = 'Error'; ExpectedRequests = 3 }
        @{ Probe = 'orgs/fixture-org/actions/permissions'; Outcome = 'Error'; ExpectedRequests = 4 }
    ) {
        $script:LimitedProbe = "https://api.github.com/$Probe"
        $script:ProbeOutcome = $Outcome
        Mock Invoke-WebRequest -ModuleName Maester {
            $Headers = @{}
            if ($Uri -eq $script:LimitedProbe) {
                if ($script:ProbeOutcome -eq 'Error') {
                    $Response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
                    $null = $Response.Headers.TryAddWithoutValidation('retry-after', '120')
                    throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Synthetic rate limit', $Response)
                }
                $Headers = @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = [DateTimeOffset]::UtcNow.AddMinutes(10).ToUnixTimeSeconds() }
            }
            $Content = switch ($Uri) {
                'https://api.github.com/user' { '{"login":"fixture-user"}' }
                'https://api.github.com/orgs/fixture-org' { '{"login":"fixture-org","plan":{"name":"enterprise"}}' }
                'https://api.github.com/user/memberships/orgs/fixture-org' { '{"state":"active","role":"admin"}' }
                'https://api.github.com/orgs/fixture-org/actions/permissions' { '{}' }
                default { throw "Unexpected request: $Uri" }
            }
            [pscustomobject]@{ Content = $Content; Headers = $Headers; StatusCode = 200 }
        }
        InModuleScope Maester -Parameters @{ Probe = $Probe; Outcome = $Outcome } {
            $Token = [System.Security.SecureString]::new()
            $Token.AppendChar('x')
            Connect-MtGitHub -Organization fixture-org -Token $Token -ApiBaseUri https://api.github.com -ApiVersion '2022-11-28' -WarningVariable Warnings -WarningAction SilentlyContinue
            # Exhausting the membership response blocks only the non-blocking administration probe.
            $Connected = $Probe -eq 'orgs/fixture-org/actions/permissions' -or ($Outcome -eq 'Success' -and $Probe -eq 'user/memberships/orgs/fixture-org')
            $__MtSession.GitHubConnection.Connected | Should -Be $Connected
            if (-not $Connected) {
                $__MtSession.GitHubConnection.FailureReason | Should -Be 'RateLimited'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            } else {
                [object]::ReferenceEquals($__MtSession.GitHubRateLimits.Connection, $__MtSession.GitHubConnection) | Should -BeTrue
                $AdminVerified = $Outcome -eq 'Success' -and $Probe -eq 'orgs/fixture-org/actions/permissions'
                $__MtSession.GitHubConnection.AdministrationPermissionVerified | Should -Be $AdminVerified
                if (-not $AdminVerified) { $Warnings -join ' ' | Should -Match 'administration.*rate limit' }
                { Invoke-MtGitHubRequest '/repository' } | Should -Throw '*rate limit*'
            }
            $__MtSession.GitHubRateLimits.Limits.Count | Should -Be 1
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times $ExpectedRequests
    }
}

Describe 'Simultaneous primary and secondary GitHub limits' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; ApiBaseUri = 'https://api.github.com'; ApiVersion = '2022-11-28' }
            $__MtSession.GitHubAuthHeader = @{}
            $__MtSession.GitHubCache = @{}
            $__MtSession.GitHubRateLimits = $null
        }
        $script:combinedCalls = 0
    }
    AfterEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache = @{}
            $__MtSession.GitHubRateLimits = $null
        }
    }

    It 'Enforces each deadline independently (<Transport>, <Scenario>)' -ForEach @(
        foreach ($transport in 'REST', 'GraphQL HTTP', 'GraphQL data') {
            foreach ($scenario in 'long primary', 'short primary', 'unknown primary', 'secondary outlasts primary') {
                @{ Transport = $transport; Scenario = $scenario }
            }
        }
    ) {
        $script:combinedTransport = $Transport
        $script:combinedHeaders = @{ 'x-ratelimit-remaining' = '0' }
        if ($Scenario -ne 'unknown primary') {
            $primarySeconds = if ($Scenario -eq 'long primary') { 3600 } else { 10 }
            $script:combinedHeaders['x-ratelimit-reset'] = [DateTimeOffset]::UtcNow.AddSeconds($primarySeconds).ToUnixTimeSeconds()
        }
        if ($Scenario -ne 'short primary') { $script:combinedHeaders['retry-after'] = '120' }
        Mock Invoke-WebRequest -ModuleName Maester {
            $script:combinedCalls++
            if ($script:combinedCalls -eq 1) {
                if ($script:combinedTransport -eq 'GraphQL data') {
                    # HTTP 200 GraphQL errors can signal the shared cooldown through Retry-After alone.
                    $message = if ($script:combinedHeaders.ContainsKey('retry-after')) { 'API rate limit exceeded' } else { 'You have exceeded a secondary rate limit.' }
                    $body = @{ data = $null; errors = @(@{ type = 'RATE_LIMITED'; message = $message }) } | ConvertTo-Json -Depth 5 -Compress
                    return [pscustomobject]@{ Content = $body; Headers = $script:combinedHeaders }
                }
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
                foreach ($key in $script:combinedHeaders.Keys) { $null = $response.Headers.TryAddWithoutValidation($key, [string]$script:combinedHeaders[$key]) }
                $err = [System.Management.Automation.ErrorRecord]::new([Microsoft.PowerShell.Commands.HttpResponseException]::new('Synthetic combined limits', $response), 'FixtureHttp', 'InvalidOperation', $null)
                $err.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"message":"You have exceeded a secondary rate limit."}')
                throw $err
            }
            [pscustomobject]@{ Content = $(if ($Method -eq 'POST') { '{"data":{"viewer":{"login":"fixture-user"}}}' } else { '{"id":101}' }); Headers = @{} }
        }
        InModuleScope Maester -Parameters @{ Transport = $Transport; Scenario = $Scenario } {
            $restRead = { Invoke-MtGitHubRequest '/repository' -DisableCache }
            $graphQLRead = { Invoke-MtGitHubGraphQLRequest -Query 'query Fixture{viewer{login}}' -Variables @{} -OperationName Fixture -DisableCache }
            $affectedRead = if ($Transport -eq 'REST') { $restRead } else { $graphQLRead }
            $otherRead = if ($Transport -eq 'REST') { $graphQLRead } else { $restRead }
            $api = if ($Transport -eq 'REST') { 'REST' } else { 'GraphQL' }
            $caught = $null
            try { & $affectedRead | Out-Null } catch { $caught = $_ }
            $caught | Should -Not -BeNullOrEmpty
            $primary = $__MtSession.GitHubRateLimits.Limits["https://api.github.com|$api"]
            $secondary = $__MtSession.GitHubRateLimits.Limits['https://api.github.com|All']
            $primary | Should -Not -BeNullOrEmpty
            $secondary | Should -Not -BeNullOrEmpty
            $primary.Kind | Should -Be 'Primary'
            $secondary.Kind | Should -Be 'Secondary'
            $secondarySeconds = if ($Scenario -eq 'short primary') { 60 } else { 120 }
            ($secondary.ResumeUtc - [DateTimeOffset]::UtcNow).TotalSeconds | Should -BeGreaterThan ($secondarySeconds - 5)
            ($secondary.ResumeUtc - [DateTimeOffset]::UtcNow).TotalSeconds | Should -BeLessOrEqual $secondarySeconds
            if ($Scenario -eq 'unknown primary') { $primary.ResumeUtc | Should -Be ([DateTimeOffset]::MaxValue) }
            elseif ($Scenario -eq 'long primary') { $primary.ResumeUtc | Should -BeGreaterThan ([DateTimeOffset]::UtcNow.AddMinutes(59)) }
            else { $primary.ResumeUtc | Should -BeLessThan $secondary.ResumeUtc }
            $expectedKind = if ($Scenario -in 'long primary', 'unknown primary') { 'Primary' } else { 'Secondary' }
            $caught.Exception.Data['GitHubRateLimit'].Kind | Should -Be $expectedKind
            @($caught.Exception.Data['GitHubRateLimits']).Count | Should -Be 2
            @(Get-MtGitHubRateLimitMessage -ErrorRecord $caught).Count | Should -Be 1
            Get-MtGitHubErrorStatusCode -ErrorRecord $caught | Should -Be $(if ($Transport -eq 'GraphQL data') { 200 } else { 429 })
            { & $affectedRead } | Should -Throw '*rate limit*'
            { & $otherRead } | Should -Throw '*rate limit*'
            $__MtSession.GitHubCache.Count | Should -Be 0
            if ($Scenario -in 'long primary', 'unknown primary') {
                $secondary.ResumeUtc = [DateTimeOffset]::UtcNow.AddSeconds(-1)
                { & $otherRead } | Should -Not -Throw
                { & $affectedRead } | Should -Throw '*rate limit*'
            } else {
                $primary.ResumeUtc = [DateTimeOffset]::UtcNow.AddSeconds(-1)
                { & $affectedRead } | Should -Throw '*rate limit*'
                { & $otherRead } | Should -Throw '*rate limit*'
                $secondary.ResumeUtc = [DateTimeOffset]::UtcNow.AddSeconds(-1)
                { & $affectedRead } | Should -Not -Throw
            }
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
    }
}
