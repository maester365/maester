BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Connect-MtGitHub' {
    BeforeEach {
        $script:savedMaesterGitHubToken = $env:MAESTER_GITHUB_TOKEN
        $script:savedGhToken            = $env:GH_TOKEN
        $env:MAESTER_GITHUB_TOKEN       = $null
        $env:GH_TOKEN                   = $null

        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache      = @{}
            # Pre-load an empty config so the lazy-load path is skipped in most tests.
            # Tests that exercise lazy-load explicitly reset this to $null.
            $__MtSession.MaesterConfig = [PSCustomObject]@{
                GlobalSettings = [PSCustomObject]@{}
            }
        }
    }

    AfterEach {
        $env:MAESTER_GITHUB_TOKEN = $script:savedMaesterGitHubToken
        $env:GH_TOKEN             = $script:savedGhToken

        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache      = @{}
            $__MtSession.MaesterConfig    = $null
        }
    }

    Context 'Failure: NotConfigured' {
        It 'Sets FailureReason = NotConfigured when no org and config has no GitHubOrganization' {
            Connect-MtGitHub
            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected     | Should -BeFalse
                $__MtSession.GitHubConnection.FailureReason | Should -Be 'NotConfigured'
            }
        }
    }

    Context 'Failure: NoToken' {
        It 'Sets FailureReason = NoToken when org is given but no token is available' {
            # Token env vars are cleared in BeforeEach; no -Token param
            Connect-MtGitHub -Organization 'myorg'
            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected     | Should -BeFalse
                $__MtSession.GitHubConnection.FailureReason | Should -Be 'NoToken'
            }
        }
    }

    Context 'Failure: TokenInvalid' {
        It 'Sets FailureReason = TokenInvalid on HTTP 401 from /user' {
            $env:MAESTER_GITHUB_TOKEN = 'bad-token'
            $fakeResp = [PSCustomObject]@{ StatusCode = 401; Headers = @{} }
            $ex = [System.Exception]::new('Unauthorized')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg'

            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected     | Should -BeFalse
                $__MtSession.GitHubConnection.FailureReason | Should -Be 'TokenInvalid'
            }
        }
    }

    Context 'Failure: OrgAccessFailed' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
        }

        It 'Sets FailureReason = OrgAccessFailed on HTTP 403 from /orgs/{org}' {
            $fakeResp = [PSCustomObject]@{ StatusCode = 403; Headers = @{} }
            $ex = [System.Exception]::new('Forbidden')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg'

            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected     | Should -BeFalse
                $__MtSession.GitHubConnection.FailureReason | Should -Be 'OrgAccessFailed'
            }
        }

        It 'Sets FailureReason = OrgAccessFailed on HTTP 404 from /orgs/{org}' {
            $fakeResp = [PSCustomObject]@{ StatusCode = 404; Headers = @{} }
            $ex = [System.Exception]::new('Not Found')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg'

            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected     | Should -BeFalse
                $__MtSession.GitHubConnection.FailureReason | Should -Be 'OrgAccessFailed'
            }
        }
    }

    Context 'Successful connection' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg","plan":{"name":"enterprise"}}' }
            }
        }

        It 'Sets Connected = $true and stores GitHubAuthHeader' {
            Connect-MtGitHub -Organization 'myorg' 3>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected     | Should -BeTrue
                $__MtSession.GitHubConnection.Organization  | Should -Be 'myorg'
                $__MtSession.GitHubConnection.TokenLogin    | Should -Be 'testuser'
                $__MtSession.GitHubAuthHeader               | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader['Authorization'] | Should -Match '^Bearer '
            }
        }

        It 'All three probes use the configured ApiBaseUri and X-GitHub-Api-Version header' {
            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'https://api.myco.ghe.com' -ApiVersion '2024-01-01' 3>$null

            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 3 -ParameterFilter {
                $Uri -match 'api\.myco\.ghe\.com' -and $Headers['X-GitHub-Api-Version'] -eq '2024-01-01'
            }
        }
    }

    Context 'Role probe' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg"}' }
            }
        }

        It 'admin + active: no warning, Role=admin, RoleVerified=$true, RoleState=active' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            $warns = @()
            Connect-MtGitHub -Organization 'myorg' -WarningAction SilentlyContinue -WarningVariable warns 3>$null
            $warns.Count | Should -Be 0
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeTrue
                $c.Role          | Should -Be 'admin'
                $c.RoleState     | Should -Be 'active'
                $c.RoleVerified  | Should -BeTrue
                $c.RoleVerificationFailureReason | Should -BeNullOrEmpty
            }
        }

        It 'admin + pending: warning mentions pending; RoleState=pending, RoleVerified=$true' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"pending","role":"admin"}' }
            }
            $warns = @()
            Connect-MtGitHub -Organization 'myorg' -WarningAction SilentlyContinue -WarningVariable warns 3>$null
            $warns.Count | Should -BeGreaterOrEqual 1
            ($warns -join ' ') | Should -Match 'pending'
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected    | Should -BeTrue
                $c.RoleState    | Should -Be 'pending'
                $c.RoleVerified | Should -BeTrue
            }
        }

        It 'member + active: warning matches admin/owner phrasing (not "owner role"); Role=member, RoleVerified=$true' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"member"}' }
            }
            $warns = @()
            Connect-MtGitHub -Organization 'myorg' -WarningAction SilentlyContinue -WarningVariable warns 3>$null
            $warns.Count | Should -BeGreaterOrEqual 1
            ($warns -join ' ') | Should -Match 'admin/owner|full CIS coverage'
            ($warns -join ' ') | Should -Not -Match 'owner role'
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected    | Should -BeTrue
                $c.Role         | Should -Be 'member'
                $c.RoleVerified | Should -BeTrue
            }
        }

        It 'unexpected role string: warning emitted; fields populated as returned' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"billing_manager"}' }
            }
            $warns = @()
            Connect-MtGitHub -Organization 'myorg' -WarningAction SilentlyContinue -WarningVariable warns 3>$null
            $warns.Count | Should -BeGreaterOrEqual 1
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected    | Should -BeTrue
                $c.Role         | Should -Be 'billing_manager'
                $c.RoleState    | Should -Be 'active'
                $c.RoleVerified | Should -BeTrue
            }
        }

        It 'probe HTTP 403: warning, RoleVerified=$false, failure reason includes 403 and api message; Connected=$true' {
            $fakeResp = [PSCustomObject]@{ StatusCode = 403; Headers = @{} }
            $ex = [System.Exception]::new('Forbidden')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Get-MtGitHubErrorStatusCode -ModuleName Maester { 403 }
            Mock Get-MtGitHubErrorMessage    -ModuleName Maester { 'Insufficient permissions to read membership.' }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } { throw $ex }

            $warns = @()
            Connect-MtGitHub -Organization 'myorg' -WarningAction SilentlyContinue -WarningVariable warns 3>$null

            $warns.Count | Should -BeGreaterOrEqual 1
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected                     | Should -BeTrue
                $c.RoleVerified                  | Should -BeFalse
                $c.RoleVerificationFailureReason | Should -Match '^403:'
                $c.RoleVerificationFailureReason | Should -Match 'Insufficient permissions'
            }
        }

        It 'probe HTTP 404: warning, RoleVerified=$false, failure reason includes 404; Connected=$true' {
            $fakeResp = [PSCustomObject]@{ StatusCode = 404; Headers = @{} }
            $ex = [System.Exception]::new('Not Found')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Get-MtGitHubErrorStatusCode -ModuleName Maester { 404 }
            Mock Get-MtGitHubErrorMessage    -ModuleName Maester { 'Not Found' }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } { throw $ex }

            $warns = @()
            Connect-MtGitHub -Organization 'myorg' -WarningAction SilentlyContinue -WarningVariable warns 3>$null

            $warns.Count | Should -BeGreaterOrEqual 1
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected                     | Should -BeTrue
                $c.RoleVerified                  | Should -BeFalse
                $c.RoleVerificationFailureReason | Should -Match '^404:'
            }
        }

        It '200 with malformed JSON body: warning, RoleVerified=$false, reason="Malformed membership response"; Connected=$true' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = 'not-json{' }
            }
            $warns = @()
            Connect-MtGitHub -Organization 'myorg' -WarningAction SilentlyContinue -WarningVariable warns 3>$null
            $warns.Count | Should -BeGreaterOrEqual 1
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected                     | Should -BeTrue
                $c.RoleVerified                  | Should -BeFalse
                $c.RoleVerificationFailureReason | Should -Be 'Malformed membership response'
            }
        }

        It '200 with valid JSON missing role field: same as malformed path; Connected=$true' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active"}' }
            }
            $warns = @()
            Connect-MtGitHub -Organization 'myorg' -WarningAction SilentlyContinue -WarningVariable warns 3>$null
            $warns.Count | Should -BeGreaterOrEqual 1
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected                     | Should -BeTrue
                $c.RoleVerified                  | Should -BeFalse
                $c.RoleVerificationFailureReason | Should -Be 'Malformed membership response'
            }
        }

        It '200 with valid JSON missing state field: same as malformed path; Connected=$true' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"role":"admin"}' }
            }
            $warns = @()
            Connect-MtGitHub -Organization 'myorg' -WarningAction SilentlyContinue -WarningVariable warns 3>$null
            $warns.Count | Should -BeGreaterOrEqual 1
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected                     | Should -BeTrue
                $c.RoleVerified                  | Should -BeFalse
                $c.RoleVerificationFailureReason | Should -Be 'Malformed membership response'
            }
        }
    }

    Context 'Config fallback: pre-loaded MaesterConfig' {
        It 'Resolves org from pre-loaded MaesterConfig without calling Get-MtMaesterConfig' {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
            InModuleScope Maester {
                $__MtSession.MaesterConfig = [PSCustomObject]@{
                    GlobalSettings = [PSCustomObject]@{
                        GitHubOrganization = 'config-org'
                    }
                }
            }
            Mock Get-MtMaesterConfig -ModuleName Maester { throw 'Get-MtMaesterConfig must not be called when config is pre-loaded' }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"config-org"}' }
            }

            Connect-MtGitHub 3>$null

            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected    | Should -BeTrue
                $__MtSession.GitHubConnection.Organization | Should -Be 'config-org'
            }
        }
    }

    Context 'Config fallback: lazy-load when MaesterConfig is null' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'

            # Reset to null so the lazy-load path fires
            InModuleScope Maester { $__MtSession.MaesterConfig = $null }

            $fakeConfig = [PSCustomObject]@{
                GlobalSettings = [PSCustomObject]@{
                    GitHubOrganization = 'lazy-org'
                    GitHubApiBaseUri   = 'https://api.lazy.ghe.com'
                    GitHubApiVersion   = '2024-06-01'
                }
            }
            Mock Get-MtMaesterConfig -ModuleName Maester { $fakeConfig }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"lazy-org"}' }
            }
        }

        It 'Lazy-loads config and resolves org when MaesterConfig is null and no -Organization supplied' {
            Connect-MtGitHub 3>$null

            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected    | Should -BeTrue
                $__MtSession.GitHubConnection.Organization | Should -Be 'lazy-org'
                # $__MtSession.MaesterConfig is now set; real Get-MtMaesterConfigGlobalSetting reads it
                $__MtSession.MaesterConfig.GlobalSettings.GitHubOrganization | Should -Be 'lazy-org'
            }
        }

        It 'Lazy-loads config for ApiBaseUri and ApiVersion when -Organization is supplied but others are omitted' {
            Connect-MtGitHub -Organization 'myorg' 3>$null

            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected  | Should -BeTrue
                $__MtSession.GitHubConnection.ApiBaseUri | Should -Be 'https://api.lazy.ghe.com'
                $__MtSession.GitHubConnection.ApiVersion | Should -Be '2024-06-01'
            }
        }

        It 'All three config-backed values (org, ApiBaseUri, ApiVersion) are resolved from lazy-loaded config' {
            Connect-MtGitHub 3>$null

            InModuleScope Maester {
                $conn = $__MtSession.GitHubConnection
                $conn.Organization | Should -Be 'lazy-org'
                $conn.ApiBaseUri   | Should -Be 'https://api.lazy.ghe.com'
                $conn.ApiVersion   | Should -Be '2024-06-01'
            }
        }
    }
}
