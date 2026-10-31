BeforeDiscovery {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'GitHub REST cache affected objects' {
    InModuleScope Maester {
        BeforeEach {
            $__MtSession.GraphCache = @{}
            $__MtSession.GitHubCache = @{}
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; ApiBaseUri = 'https://api.github.com'; ApiVersion = '2022-11-28' }
            $__MtSession.GitHubAuthHeader = @{}
            $__MtSession.GitHubRateLimits = $null
            Mock Invoke-WebRequest { [pscustomobject]@{ Content = $(if ($Uri -like '*/collaborators*') { '[{"id":1}]' } else { '{"id":100}' }); Headers = @{} } }
        }
        AfterEach {
            $__MtSession.GitHubCache = @{}
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
        }
        It 'Retains organization and repository records from metadata-only reads' {
            $null = Invoke-MtGitHubRequest -RelativeUri '/orgs/fixture-org' -IncludeMetadata -ApiVersion '2026-03-10'
            $null = Invoke-MtGitHubRequest -RelativeUri '/repos/fixture-org/example/collaborators' -IncludeMetadata -Paginate -MaxPages 2 -ApiVersion '2026-03-10'
            $records = @(Get-MtAffectedObjectFromCache)
            $records.Count | Should -Be 2
            $records.Type | Should -Contain 'GitHubOrganization'
            $records.Type | Should -Contain 'GitHubRepository'
            $records.Id | Should -Contain 'fixture-org/example'
            ($records.SourceUri -join '') | Should -Not -Match '\|'
        }
        It 'Deduplicates mixed legacy and metadata reads without merging their caches' {
            $null = Invoke-MtGitHubRequest -RelativeUri '/orgs/fixture-org' -IncludeMetadata -ApiVersion '2026-03-10'
            $null = Invoke-MtGitHubRequest -RelativeUri '/orgs/fixture-org'
            $__MtSession.GitHubCache.Count | Should -Be 2
            @(Get-MtAffectedObjectFromCache).Count | Should -Be 1
        }
        It 'Ignores malformed and unrelated keys including opaque GraphQL keys' {
            foreach ($key in @(
                'GraphQL|https://api.github.com/orgs/private|opaque',
                'https://api.github.com/orgs/unkeyed',
                '2026-03-10|https://user:password@api.github.com/orgs/credentials',
                '2026-03-10|https://api.github.com/orgs/fragment#secret',
                '2026-03-10|https://api.github.com/orgs/space name',
                'Metadata|GET|nonsense|https://api.github.com/orgs/invalid-version|Paginate=False',
                'Metadata|POST|2026-03-10|https://api.github.com/orgs/post|Paginate=False',
                'Metadata|GET|2026-03-10|https://api.github.com/orgs/bad|Paginate=True|unexpected=value',
                '2026-03-10|not-a-uri', '2026-03-10|http://api.github.com/orgs/insecure'
            )) { $__MtSession.GitHubCache[$key] = @{} }
            @(Get-MtAffectedObjectFromCache).Count | Should -Be 0
        }
    }
}
