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
            Mock Get-MtUserInteractive -ModuleName Maester { $false }

            # Token env vars are cleared in BeforeEach; no -Token param; non-interactive sessions cannot device-auth.
            Connect-MtGitHub -Organization 'myorg'
            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected     | Should -BeFalse
                $__MtSession.GitHubConnection.FailureReason | Should -Be 'NoToken'
            }
        }
    }

    Context 'Maester GitHub App device flow' {
        BeforeEach {
            Mock Get-MtUserInteractive -ModuleName Maester { $true }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } {
                [PSCustomObject]@{ Content = '{"enabled_repositories":"all"}'; StatusCode = 200 }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg","plan":{"name":"enterprise"}}' }
            }
        }

        It 'Uses the Maester GitHub App client ID when no token is supplied' {
            $expiresAt = [datetime]'2030-01-01T00:00:00Z'
            Mock Get-MtGitHubAppDeviceToken -ModuleName Maester -ParameterFilter { $ClientId -eq 'Iv23liV3mw0hSq0gn957' } {
                [PSCustomObject]@{ AccessToken = 'ghu_device'; ExpiresAt = $expiresAt; FailureReason = $null }
            }

            Connect-MtGitHub -Organization 'myorg' 3>$null

            Should -Invoke Get-MtGitHubAppDeviceToken -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $ClientId -eq 'Iv23liV3mw0hSq0gn957'
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 4 -ParameterFilter {
                $Headers['Authorization'] -eq 'Bearer ghu_device'
            }
            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected          | Should -BeTrue
                $__MtSession.GitHubConnection.AuthenticationType | Should -Be 'GitHubAppDeviceFlow'
                $__MtSession.GitHubConnection.TokenExpiresAt     | Should -Be ([datetime]'2030-01-01T00:00:00Z')
                $__MtSession.GitHubAuthHeader.Authorization      | Should -Be 'Bearer ghu_device'
            }
        }

        It 'Records the device flow failure reason and does not retain an auth header' {
            Mock Get-MtGitHubAppDeviceToken -ModuleName Maester {
                [PSCustomObject]@{ AccessToken = $null; ExpiresAt = $null; FailureReason = 'GitHubDeviceFlowDenied' }
            }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected     | Should -BeFalse
                $__MtSession.GitHubConnection.FailureReason | Should -Be 'GitHubDeviceFlowDenied'
                $__MtSession.GitHubAuthHeader               | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Maester GitHub App organization install retry' {
        BeforeEach {
            $script:membershipProbeCount = 0

            Mock Get-MtUserInteractive -ModuleName Maester { $true }
            Mock Get-MtGitHubAppDeviceToken -ModuleName Maester {
                [PSCustomObject]@{ AccessToken = 'ghu_device'; ExpiresAt = $null; FailureReason = $null }
            }
            Mock Request-MtGitHubAppOrganizationInstall -ModuleName Maester { $true }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } {
                [PSCustomObject]@{ Content = '{"enabled_repositories":"all"}'; StatusCode = 200 }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg","plan":{"name":"enterprise"}}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                $script:membershipProbeCount++
                if ($script:membershipProbeCount -eq 1) {
                    $fakeResp = [PSCustomObject]@{ StatusCode = 403; Headers = @{} }
                    $ex = [System.Exception]::new('You do not have access to this organization membership.')
                    Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
                    throw $ex
                }

                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
        }

        It 'Prompts for org app install once and retries the membership probe' {
            Connect-MtGitHub -Organization 'myorg' 3>$null

            Should -Invoke Request-MtGitHubAppOrganizationInstall -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Organization -eq 'myorg' -and
                $InstallUrl -eq 'https://github.com/apps/maester-cli/installations/new' -and
                $Reason -match 'organization membership'
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 2 -Exactly -ParameterFilter {
                $Uri -eq 'https://api.github.com/user/memberships/orgs/myorg'
            }
            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected          | Should -BeTrue
                $__MtSession.GitHubConnection.AuthenticationType | Should -Be 'GitHubAppDeviceFlow'
                $__MtSession.GitHubAuthHeader.Authorization      | Should -Be 'Bearer ghu_device'
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

    Context 'Failure: ApiBaseUriFailed' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
        }

        It 'Sets FailureReason = ApiBaseUriFailed when /user throws with no Response/StatusCode (DNS/TLS/transport)' {
            # Plain exception with no Response — Get-MtGitHubErrorStatusCode returns $null,
            # which models DNS failure, TLS handshake failure, connection refused, or an
            # unreachable GHE base URI. Must not be classified as TokenInvalid.
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                throw [System.Exception]::new('No such host is known')
            }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'ApiBaseUriFailed'
                $c.FailureReason | Should -Not -Be 'TokenInvalid'
                # Security property: failed connection must not leave a Bearer header in session.
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Failure: ApiUnavailable' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
        }

        It 'Sets FailureReason = ApiUnavailable when /user returns HTTP 500 (server error, URI is fine)' {
            # 5xx means GitHub responded — the base URI resolved and TLS succeeded — but the
            # service itself is failing. Must not be conflated with TokenInvalid or ApiBaseUriFailed.
            $fakeResp = [PSCustomObject]@{ StatusCode = 500; Headers = @{} }
            $ex = [System.Exception]::new('Internal Server Error')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Get-MtGitHubErrorStatusCode -ModuleName Maester { 500 }
            Mock Get-MtGitHubErrorMessage    -ModuleName Maester { 'Internal Server Error' }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'ApiUnavailable'
                $c.FailureReason | Should -Not -Be 'TokenInvalid'
                $c.FailureReason | Should -Not -Be 'ApiBaseUriFailed'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It 'Sets FailureReason = ApiUnavailable when /user returns HTTP 503' {
            $fakeResp = [PSCustomObject]@{ StatusCode = 503; Headers = @{} }
            $ex = [System.Exception]::new('Service Unavailable')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Get-MtGitHubErrorStatusCode -ModuleName Maester { 503 }
            Mock Get-MtGitHubErrorMessage    -ModuleName Maester { 'Service Unavailable' }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'ApiUnavailable'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
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

        It 'Sets FailureReason = ApiBaseUriFailed when /orgs/{org} throws transport exception (no Response)' {
            # /user succeeded, then DNS/TLS fails on the second probe. Must not be classified
            # as OrgAccessFailed — the org access can't be determined when there's no HTTP response.
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/' } {
                throw [System.Exception]::new('Connection reset by peer')
            }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'ApiBaseUriFailed'
                $c.FailureReason | Should -Not -Be 'OrgAccessFailed'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It 'Sets FailureReason = ApiUnavailable when /orgs/{org} returns HTTP 500' {
            $fakeResp = [PSCustomObject]@{ StatusCode = 500; Headers = @{} }
            $ex = [System.Exception]::new('Internal Server Error')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Get-MtGitHubErrorStatusCode -ModuleName Maester { 500 }
            Mock Get-MtGitHubErrorMessage    -ModuleName Maester { 'Internal Server Error' }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'ApiUnavailable'
                $c.FailureReason | Should -Not -Be 'OrgAccessFailed'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Successful connection' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } {
                [PSCustomObject]@{ Content = '{"enabled_repositories":"all"}'; StatusCode = 200 }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg","plan":{"name":"enterprise"}}' }
            }
        }

        It 'Sets Connected = $true and stores GitHubAuthHeader' {
            Connect-MtGitHub -Organization 'myorg' 3>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected                        | Should -BeTrue
                $__MtSession.GitHubConnection.Organization                     | Should -Be 'myorg'
                $__MtSession.GitHubConnection.TokenLogin                       | Should -Be 'testuser'
                $__MtSession.GitHubConnection.AdministrationPermissionVerified | Should -BeTrue
                $__MtSession.GitHubAuthHeader                                  | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader['Authorization']                 | Should -Match '^Bearer '
            }
        }

        It 'All four probes use the configured ApiBaseUri and X-GitHub-Api-Version header' {
            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'https://api.myco.ghe.com' -ApiVersion '2024-01-01' 3>$null

            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 4 -ParameterFilter {
                $Uri -match 'api\.myco\.ghe\.com' -and $Headers['X-GitHub-Api-Version'] -eq '2024-01-01'
            }
        }

        It 'GHE.com data residency: all four endpoint paths target the configured base URI' {
            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'https://api.octocorp.ghe.com' 3>$null

            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter {
                $Uri -eq 'https://api.octocorp.ghe.com/user'
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter {
                $Uri -eq 'https://api.octocorp.ghe.com/orgs/myorg'
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter {
                $Uri -eq 'https://api.octocorp.ghe.com/user/memberships/orgs/myorg'
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter {
                $Uri -eq 'https://api.octocorp.ghe.com/orgs/myorg/actions/permissions'
            }
        }
    }

    Context 'Role probe' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } {
                [PSCustomObject]@{ Content = '{}'; StatusCode = 200 }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
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
                $c.AdministrationPermissionVerified | Should -BeTrue
            }
        }

        It 'admin + pending: fails connection with FailureReason = OrgMembershipPending and clears auth header' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"pending","role":"admin"}' }
            }
            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'OrgMembershipPending'
                # Security property: failed connection must not leave a Bearer header in session.
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It 'member + pending: fails connection with FailureReason = OrgMembershipPending' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"pending","role":"member"}' }
            }
            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'OrgMembershipPending'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
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

    }

    Context 'Administration permission probe' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg"}' }
            }
        }

        It 'admin + active + admin probe 200: Connected=true, AdministrationPermissionVerified=true, no admin warning, four IWR calls' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } {
                [PSCustomObject]@{ Content = '{"enabled_repositories":"all"}'; StatusCode = 200 }
            }

            $warns = @()
            Connect-MtGitHub -Organization 'myorg' -WarningAction SilentlyContinue -WarningVariable warns 3>$null

            ($warns -join ' ') | Should -Not -Match 'administration API access'
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected                                    | Should -BeTrue
                $c.AdministrationPermissionVerified             | Should -BeTrue
                $c.AdministrationPermissionFailureReason        | Should -BeNullOrEmpty
                $c.AdministrationPermissionStatusCode           | Should -Be 200
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 4
        }

        It 'admin + active + admin probe 403: Connected=true, FailureReason=null, AdministrationPermissionVerified=false, warning mentions both permission models' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            $fakeResp = [PSCustomObject]@{
                StatusCode = 403
                Headers    = @{ 'x-accepted-github-permissions' = 'administration=read' }
            }
            $ex = [System.Exception]::new('Forbidden')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Get-MtGitHubErrorStatusCode -ModuleName Maester { 403 }
            Mock Get-MtGitHubErrorMessage    -ModuleName Maester { 'Resource not accessible by personal access token' }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } { throw $ex }

            $warns = @()
            Connect-MtGitHub -Organization 'myorg' -WarningAction SilentlyContinue -WarningVariable warns 3>$null

            $combined = $warns -join ' '
            $combined | Should -Match 'admin:org'
            $combined | Should -Match 'Administration: read'
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected                                    | Should -BeTrue
                $c.FailureReason                                | Should -BeNullOrEmpty
                $c.Role                                         | Should -Be 'admin'
                $c.AdministrationPermissionVerified             | Should -BeFalse
                $c.AdministrationPermissionStatusCode           | Should -Be 403
                $c.AdministrationPermissionFailureReason        | Should -Match 'HTTP 403'
                $c.AdministrationPermissionAcceptedPermissions  | Should -Be 'administration=read'
            }
        }

        It 'member + active + admin probe 403: emits both role and admin-permission warnings' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"member"}' }
            }
            $fakeResp = [PSCustomObject]@{ StatusCode = 403; Headers = @{} }
            $ex = [System.Exception]::new('Forbidden')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Get-MtGitHubErrorStatusCode -ModuleName Maester { 403 }
            Mock Get-MtGitHubErrorMessage    -ModuleName Maester { 'Resource not accessible' }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } { throw $ex }

            $warns = @()
            Connect-MtGitHub -Organization 'myorg' -WarningAction SilentlyContinue -WarningVariable warns 3>$null

            $warns.Count | Should -BeGreaterOrEqual 2
            $combined = $warns -join ' '
            $combined | Should -Match 'admin/owner|full CIS coverage'
            $combined | Should -Match 'administration API access|Administration: read'
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected                        | Should -BeTrue
                $c.Role                             | Should -Be 'member'
                $c.AdministrationPermissionVerified | Should -BeFalse
            }
        }
    }

    Context 'Failure: OrgMembershipFailed' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg"}' }
            }
        }

        It 'Membership HTTP 403 fails connection with FailureReason = OrgMembershipFailed' {
            $fakeResp = [PSCustomObject]@{ StatusCode = 403; Headers = @{} }
            $ex = [System.Exception]::new('Forbidden')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Get-MtGitHubErrorStatusCode -ModuleName Maester { 403 }
            Mock Get-MtGitHubErrorMessage    -ModuleName Maester { 'Insufficient permissions to read membership.' }
            Mock Request-MtGitHubAppOrganizationInstall -ModuleName Maester { throw 'Token-based auth must not prompt for GitHub App installation.' }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'OrgMembershipFailed'
                # Security property: failed connection must not leave a Bearer header in session.
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It 'Membership HTTP 404 fails connection with FailureReason = OrgMembershipFailed' {
            $fakeResp = [PSCustomObject]@{ StatusCode = 404; Headers = @{} }
            $ex = [System.Exception]::new('Not Found')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Get-MtGitHubErrorStatusCode -ModuleName Maester { 404 }
            Mock Get-MtGitHubErrorMessage    -ModuleName Maester { 'Not Found' }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'OrgMembershipFailed'
                # Security property: failed connection must not leave a Bearer header in session.
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It '200 with malformed JSON body fails connection with FailureReason = OrgMembershipFailed' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = 'not-json{' }
            }
            Connect-MtGitHub -Organization 'myorg' 6>$null
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'OrgMembershipFailed'
                # Security property: failed connection must not leave a Bearer header in session.
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It '200 with valid JSON missing role field fails connection with FailureReason = OrgMembershipFailed' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active"}' }
            }
            Connect-MtGitHub -Organization 'myorg' 6>$null
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'OrgMembershipFailed'
                # Security property: failed connection must not leave a Bearer header in session.
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It '200 with valid JSON missing state field fails connection with FailureReason = OrgMembershipFailed' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"role":"admin"}' }
            }
            Connect-MtGitHub -Organization 'myorg' 6>$null
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'OrgMembershipFailed'
                # Security property: failed connection must not leave a Bearer header in session.
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It 'Sets FailureReason = ApiBaseUriFailed when /memberships/ throws transport exception (no Response)' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                throw [System.Exception]::new('No such host is known')
            }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'ApiBaseUriFailed'
                $c.FailureReason | Should -Not -Be 'OrgMembershipFailed'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It 'Sets FailureReason = ApiUnavailable when /memberships/ returns HTTP 503' {
            $fakeResp = [PSCustomObject]@{ StatusCode = 503; Headers = @{} }
            $ex = [System.Exception]::new('Service Unavailable')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Get-MtGitHubErrorStatusCode -ModuleName Maester { 503 }
            Mock Get-MtGitHubErrorMessage    -ModuleName Maester { 'Service Unavailable' }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'ApiUnavailable'
                $c.FailureReason | Should -Not -Be 'OrgMembershipFailed'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Failure: RateLimited' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
        }

        It '/user 403 with x-ratelimit-remaining=0 sets FailureReason=RateLimited and clears auth header' {
            $fakeResp = [PSCustomObject]@{
                StatusCode = 403
                Headers    = @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = '9999999999' }
            }
            $ex = [System.Exception]::new('Forbidden')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'RateLimited'
                $c.FailureReason | Should -Not -Be 'TokenInvalid'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It '/orgs/{org} 429 with retry-after sets FailureReason=RateLimited (not OrgAccessFailed)' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            $fakeResp = [PSCustomObject]@{
                StatusCode = 429
                Headers    = @{ 'retry-after' = '60' }
            }
            $ex = [System.Exception]::new('Too Many Requests')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'RateLimited'
                $c.FailureReason | Should -Not -Be 'OrgAccessFailed'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It '/memberships/ 403 with x-ratelimit-remaining=0 sets FailureReason=RateLimited (not OrgMembershipFailed)' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg"}' }
            }
            $fakeResp = [PSCustomObject]@{
                StatusCode = 403
                Headers    = @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = '9999999999' }
            }
            $ex = [System.Exception]::new('Forbidden')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'RateLimited'
                $c.FailureReason | Should -Not -Be 'OrgMembershipFailed'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It 'Admin probe 429 with retry-after: Connected=true, FailureReason=null, admin permission marked rate-limited, warning mentions rate limit' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            $fakeResp = [PSCustomObject]@{
                StatusCode = 429
                Headers    = @{ 'retry-after' = '90' }
            }
            $ex = [System.Exception]::new('Too Many Requests')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } { throw $ex }

            $warns = @()
            Connect-MtGitHub -Organization 'myorg' -WarningAction SilentlyContinue -WarningVariable warns 3>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected                                | Should -BeTrue
                $c.FailureReason                            | Should -BeNullOrEmpty
                $c.AdministrationPermissionVerified         | Should -BeFalse
                $c.AdministrationPermissionStatusCode       | Should -Be 429
                $c.AdministrationPermissionFailureReason    | Should -Match 'rate limit'
            }
            ($warns -join ' ') | Should -Match 'rate limit'
        }
    }

    Context 'Failure: TokenForbidden' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
        }

        It '/user 403 with x-ratelimit-remaining=0 remains RateLimited' {
            $fakeResp = [PSCustomObject]@{
                StatusCode = 403
                Headers    = @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = '9999999999' }
            }
            $ex = [System.Exception]::new('Forbidden')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'RateLimited'
                $c.FailureReason | Should -Not -Be 'TokenForbidden'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It '/user 403 without rate-limit headers sets FailureReason = TokenForbidden' {
            $fakeResp = [PSCustomObject]@{ StatusCode = 403; Headers = @{} }
            $ex = [System.Exception]::new('Forbidden')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'TokenForbidden'
                $c.FailureReason | Should -Not -Be 'RateLimited'
                $c.FailureReason | Should -Not -Be 'TokenInvalid'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Cache seeding' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } {
                [PSCustomObject]@{ Content = '{"enabled_repositories":"all"}'; StatusCode = 200 }
            }
            Mock Get-MtGitHubCacheKey -ModuleName Maester {
                "$ApiVersion|$AbsoluteUri"
            }
        }

        It 'Seeds the connected organization response with the exact Invoke-MtGitHubRequest cache key' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/acme-co-2024$' } {
                [PSCustomObject]@{ Content = '{"login":"acme-co-2024","plan":{"name":"enterprise"}}' }
            }

            Connect-MtGitHub -Organization 'acme-co-2024' 3>$null

            InModuleScope Maester {
                # Literal-key assertion protects the encoding contract; GitHub org logins are ASCII.
                $__MtSession.GitHubCache.ContainsKey('2022-11-28|https://api.github.com/orgs/acme-co-2024') | Should -BeTrue
                $__MtSession.GitHubCache.Count | Should -Be 1
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 4
            Should -Invoke Get-MtGitHubCacheKey -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                $ApiVersion -eq '2022-11-28' -and $AbsoluteUri -eq 'https://api.github.com/orgs/acme-co-2024'
            }

            InModuleScope Maester {
                $org = Get-MtGitHubOrganization
                $org.login | Should -Be 'acme-co-2024'
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 4
            Should -Invoke Get-MtGitHubCacheKey -ModuleName Maester -Exactly -Times 2 -ParameterFilter {
                $ApiVersion -eq '2022-11-28' -and $AbsoluteUri -eq 'https://api.github.com/orgs/acme-co-2024'
            }
        }

        It 'Probe 2 malformed JSON returns OrgAccessFailed without seeding cache or auth state' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = 'not-json{' }
            }

            $info = @()
            Connect-MtGitHub -Organization 'myorg' -InformationAction SilentlyContinue -InformationVariable info

            ($info -join ' ') | Should -Match 'could not be parsed as JSON|proxy is modifying response bodies'
            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'OrgAccessFailed'
                $c.FailureReason | Should -Not -Be 'ApiBaseUriFailed'
                $__MtSession.GitHubCache.Count | Should -Be 0
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It 'Probe 3 failure leaves cache empty and auth state unset' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = 'not-json{' }
            }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'OrgMembershipFailed'
                $__MtSession.GitHubCache.Count | Should -Be 0
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It 'Probe 4 failure still connects and still seeds the organization cache' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg"}' }
            }
            $fakeResp = [PSCustomObject]@{ StatusCode = 403; Headers = @{} }
            $ex = [System.Exception]::new('Forbidden')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } { throw $ex }

            $warns = @()
            Connect-MtGitHub -Organization 'myorg' -WarningAction SilentlyContinue -WarningVariable warns 3>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected | Should -BeTrue
                $c.AdministrationPermissionVerified | Should -BeFalse
                $__MtSession.GitHubCache.ContainsKey('2022-11-28|https://api.github.com/orgs/myorg') | Should -BeTrue
                $__MtSession.GitHubCache.Count | Should -Be 1
            }
        }
    }

    Context 'Failure: InvalidApiBaseUri' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
        }

        It 'Config http:// URI fails before any web request' {
            InModuleScope Maester {
                $__MtSession.MaesterConfig = [PSCustomObject]@{
                    GlobalSettings = [PSCustomObject]@{
                        GitHubApiBaseUri = 'http://api.example.com'
                    }
                }
            }
            Mock Invoke-WebRequest -ModuleName Maester { throw 'Invoke-WebRequest must not be called when ApiBaseUri is invalid' }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'InvalidApiBaseUri'
                # Security property: invalid URI must short-circuit before headers are stored.
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        }

        It 'Config non-URI value fails before any web request' {
            InModuleScope Maester {
                $__MtSession.MaesterConfig = [PSCustomObject]@{
                    GlobalSettings = [PSCustomObject]@{
                        GitHubApiBaseUri = 'not-a-uri'
                    }
                }
            }
            Mock Invoke-WebRequest -ModuleName Maester { throw 'Invoke-WebRequest must not be called when ApiBaseUri is invalid' }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'InvalidApiBaseUri'
                # Security property: invalid URI must short-circuit before headers are stored.
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        }

        It 'Parameter -ApiBaseUri http:// fails before any web request and clears prior session state' {
            # Pre-seed a stale session to prove the parameter validation path no longer throws
            # before the session-clear step at the top of Connect-MtGitHub runs.
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'stale' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer stale-token' }
            }
            Mock Invoke-WebRequest -ModuleName Maester { throw 'Invoke-WebRequest must not be called when ApiBaseUri is invalid' }

            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'http://api.example.com' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'InvalidApiBaseUri'
                # Stale session state must be cleared even when the parameter value is rejected.
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        }

        It 'Parameter -ApiBaseUri "not-a-uri" fails before any web request and clears prior session state' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'stale' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer stale-token' }
            }
            Mock Invoke-WebRequest -ModuleName Maester { throw 'Invoke-WebRequest must not be called when ApiBaseUri is invalid' }

            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'not-a-uri' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'InvalidApiBaseUri'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        }

        It 'Parameter https URI with trailing slash still works and is trimmed' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } {
                [PSCustomObject]@{ Content = '{}'; StatusCode = 200 }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg"}' }
            }

            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'https://api.github.com/' 3>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected  | Should -BeTrue
                $c.ApiBaseUri | Should -Be 'https://api.github.com'
            }
        }

        It 'api.github.com (SaaS) passes the host allowlist' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } {
                [PSCustomObject]@{ Content = '{}'; StatusCode = 200 }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg"}' }
            }

            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'https://api.github.com' 3>$null

            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected  | Should -BeTrue
                $__MtSession.GitHubConnection.ApiBaseUri | Should -Be 'https://api.github.com'
            }
        }

        It 'api.<subdomain>.ghe.com (GHE.com data residency) passes the host allowlist' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } {
                [PSCustomObject]@{ Content = '{}'; StatusCode = 200 }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg"}' }
            }

            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'https://api.octocorp.ghe.com' 3>$null

            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected  | Should -BeTrue
                $__MtSession.GitHubConnection.ApiBaseUri | Should -Be 'https://api.octocorp.ghe.com'
            }
        }

        It 'Non-allowlisted https host fails before any web request and clears prior session state' {
            # Pre-seed a stale session to confirm session-clear runs before host validation rejects the URI.
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'stale' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer stale-token' }
            }
            Mock Invoke-WebRequest -ModuleName Maester { throw 'Invoke-WebRequest must not be called when ApiBaseUri host is not allowlisted' }

            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'https://evil.example.com' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'InvalidApiBaseUri'
                # Security property: GitHub tokens must never be sent to non-GitHub hosts; auth header must be cleared.
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        }

        It 'Non-allowlisted https host with /api/v3 path (GHES on-prem shape) is rejected' {
            Mock Invoke-WebRequest -ModuleName Maester { throw 'Invoke-WebRequest must not be called when ApiBaseUri host is not allowlisted' }

            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'https://github.example.com/api/v3' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'InvalidApiBaseUri'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        }

        It 'Allowlisted host with a query string is rejected before any web request' {
            Mock Invoke-WebRequest -ModuleName Maester { throw 'Invoke-WebRequest must not be called when ApiBaseUri has a query string' }

            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'https://api.github.com?foo=bar' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'InvalidApiBaseUri'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        }

        It 'Allowlisted host with a fragment is rejected before any web request' {
            Mock Invoke-WebRequest -ModuleName Maester { throw 'Invoke-WebRequest must not be called when ApiBaseUri has a fragment' }

            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'https://api.github.com#frag' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'InvalidApiBaseUri'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        }

        It 'Allowlisted host with non-default port is rejected before any web request' {
            Mock Invoke-WebRequest -ModuleName Maester { throw 'Invoke-WebRequest must not be called when ApiBaseUri uses a non-default port' }

            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'https://api.github.com:8443' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'InvalidApiBaseUri'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        }

        It 'Allowlisted host with extra path component is rejected' {
            # api.github.com/api/v3 has the right host but a non-root path; reject so the GitHub token isn't
            # sent to an unexpected endpoint that could be a proxy or path-rewriting middleware.
            Mock Invoke-WebRequest -ModuleName Maester { throw 'Invoke-WebRequest must not be called when ApiBaseUri has a non-root path' }

            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'https://api.github.com/api/v3' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'InvalidApiBaseUri'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
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
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } {
                [PSCustomObject]@{ Content = '{}'; StatusCode = 200 }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
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
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } {
                [PSCustomObject]@{ Content = '{}'; StatusCode = 200 }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
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

    Context 'Failure: InvalidApiVersion' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
        }

        It 'Config GitHubApiVersion = "latest" fails before any web request' {
            InModuleScope Maester {
                $__MtSession.MaesterConfig = [PSCustomObject]@{
                    GlobalSettings = [PSCustomObject]@{
                        GitHubApiVersion = 'latest'
                    }
                }
            }
            Mock Invoke-WebRequest -ModuleName Maester { throw 'Invoke-WebRequest must not be called when ApiVersion is invalid' }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'InvalidApiVersion'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        }

        It 'Config GitHubApiVersion with valid format but /user returns 410: InvalidApiVersion (not TokenInvalid)' {
            InModuleScope Maester {
                $__MtSession.MaesterConfig = [PSCustomObject]@{
                    GlobalSettings = [PSCustomObject]@{
                        GitHubApiVersion = '2020-01-01'
                    }
                }
            }
            $fakeResp = [PSCustomObject]@{ StatusCode = 410; Headers = @{} }
            $ex = [System.Exception]::new('Gone')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Get-MtGitHubErrorStatusCode -ModuleName Maester { 410 }
            Mock Get-MtGitHubErrorMessage    -ModuleName Maester { 'API version is not supported' }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'InvalidApiVersion'
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }

        It 'Parameter -ApiVersion "latest" sets InvalidApiVersion and clears prior session state' {
            # Pre-seed a stale session to prove the function clears it before failing.
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'stale' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer stale-token' }
            }
            Mock Invoke-WebRequest -ModuleName Maester { throw 'Invoke-WebRequest must not be called when ApiVersion is invalid' }

            Connect-MtGitHub -Organization 'myorg' -ApiVersion 'latest' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'InvalidApiVersion'
                # Stale auth header must be cleared even though the failure path runs early.
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        }

        It '/user 400 with "Not a supported version" message maps to InvalidApiVersion (not TokenInvalid)' {
            $fakeResp = [PSCustomObject]@{ StatusCode = 400; Headers = @{} }
            $ex = [System.Exception]::new('Bad Request')
            Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
            Mock Get-MtGitHubErrorStatusCode -ModuleName Maester { 400 }
            Mock Get-MtGitHubErrorMessage    -ModuleName Maester { 'Not a supported version' }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } { throw $ex }

            Connect-MtGitHub -Organization 'myorg' -ApiVersion '2024-01-01' 6>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected     | Should -BeFalse
                $c.FailureReason | Should -Be 'InvalidApiVersion'
            }
        }

        It 'Parameter -ApiVersion "2024-01-01" passes local format validation and reaches /user header' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } {
                [PSCustomObject]@{ Content = '{}'; StatusCode = 200 }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg"}' }
            }

            Connect-MtGitHub -Organization 'myorg' -ApiVersion '2024-01-01' 3>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected  | Should -BeTrue
                $c.ApiVersion | Should -Be '2024-01-01'
                $__MtSession.GitHubAuthHeader['X-GitHub-Api-Version'] | Should -Be '2024-01-01'
            }
        }
    }

    Context 'Whitespace trimming on resolved values' {
        BeforeEach {
            $env:MAESTER_GITHUB_TOKEN = 'valid-token'
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/actions/permissions$' } {
                [PSCustomObject]@{ Content = '{}'; StatusCode = 200 }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/memberships/' } {
                [PSCustomObject]@{ Content = '{"state":"active","role":"admin"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '^https?://[^/]+/orgs/[^/]+$' } {
                [PSCustomObject]@{ Content = '{"login":"myorg"}' }
            }
        }

        It 'Trims surrounding whitespace from -Organization parameter' {
            Connect-MtGitHub -Organization "  myorg`t" 3>$null

            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected    | Should -BeTrue
                $__MtSession.GitHubConnection.Organization | Should -Be 'myorg'
            }
            # Probe URIs must use the trimmed org, not URL-encoded whitespace.
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter {
                $Uri -eq 'https://api.github.com/orgs/myorg'
            }
        }

        It 'Trims surrounding whitespace from config-supplied GitHubOrganization' {
            InModuleScope Maester {
                $__MtSession.MaesterConfig = [PSCustomObject]@{
                    GlobalSettings = [PSCustomObject]@{
                        GitHubOrganization = "  myorg `n"
                    }
                }
            }

            Connect-MtGitHub 3>$null

            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected    | Should -BeTrue
                $__MtSession.GitHubConnection.Organization | Should -Be 'myorg'
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter {
                $Uri -eq 'https://api.github.com/orgs/myorg'
            }
        }

        It 'Trims surrounding whitespace from -ApiVersion parameter before validation' {
            Connect-MtGitHub -Organization 'myorg' -ApiVersion "  2024-01-01`t" 3>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected  | Should -BeTrue
                $c.ApiVersion | Should -Be '2024-01-01'
                $__MtSession.GitHubAuthHeader['X-GitHub-Api-Version'] | Should -Be '2024-01-01'
            }
        }

        It 'Trims surrounding whitespace from config-supplied GitHubApiVersion before validation' {
            InModuleScope Maester {
                $__MtSession.MaesterConfig = [PSCustomObject]@{
                    GlobalSettings = [PSCustomObject]@{
                        GitHubApiVersion = " 2024-06-01 "
                    }
                }
            }

            Connect-MtGitHub -Organization 'myorg' 3>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected  | Should -BeTrue
                $c.ApiVersion | Should -Be '2024-06-01'
            }
        }

        It 'Trims surrounding whitespace from -ApiBaseUri parameter before validation' {
            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri ' https://api.github.com ' 3>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected  | Should -BeTrue
                $c.ApiBaseUri | Should -Be 'https://api.github.com'
            }
            # Probe URI must be clean — no URL-encoded whitespace prefix/suffix that would 404.
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter {
                $Uri -eq 'https://api.github.com/user'
            }
        }

        It 'Trims surrounding whitespace from -ApiBaseUri parameter combined with trailing slash' {
            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'https://api.github.com/ ' 3>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected  | Should -BeTrue
                $c.ApiBaseUri | Should -Be 'https://api.github.com'
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter {
                $Uri -eq 'https://api.github.com/user'
            }
        }

        It 'Trims surrounding whitespace from config-supplied GitHubApiBaseUri before validation' {
            InModuleScope Maester {
                $__MtSession.MaesterConfig = [PSCustomObject]@{
                    GlobalSettings = [PSCustomObject]@{
                        GitHubApiBaseUri = ' https://api.github.com/ '
                    }
                }
            }

            Connect-MtGitHub -Organization 'myorg' 3>$null

            InModuleScope Maester {
                $c = $__MtSession.GitHubConnection
                $c.Connected  | Should -BeTrue
                $c.ApiBaseUri | Should -Be 'https://api.github.com'
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter {
                $Uri -eq 'https://api.github.com/user'
            }
        }
    }
}
