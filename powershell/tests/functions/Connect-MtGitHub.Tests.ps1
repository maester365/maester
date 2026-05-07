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
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/' } {
                [PSCustomObject]@{ Content = '{"login":"myorg","plan":{"name":"enterprise"}}' }
            }
        }

        It 'Sets Connected = $true and stores GitHubAuthHeader' {
            Connect-MtGitHub -Organization 'myorg'
            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected     | Should -BeTrue
                $__MtSession.GitHubConnection.Organization  | Should -Be 'myorg'
                $__MtSession.GitHubConnection.TokenLogin    | Should -Be 'testuser'
                $__MtSession.GitHubAuthHeader               | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader['Authorization'] | Should -Match '^Bearer '
            }
        }

        It 'Both probes use the configured ApiBaseUri and X-GitHub-Api-Version header' {
            Connect-MtGitHub -Organization 'myorg' -ApiBaseUri 'https://api.myco.ghe.com' -ApiVersion '2024-01-01'

            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 2 -ParameterFilter {
                $Uri -match 'api\.myco\.ghe\.com' -and $Headers['X-GitHub-Api-Version'] -eq '2024-01-01'
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
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/' } {
                [PSCustomObject]@{ Content = '{"login":"config-org"}' }
            }

            Connect-MtGitHub

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
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/user$' } {
                [PSCustomObject]@{ Content = '{"login":"testuser"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/orgs/' } {
                [PSCustomObject]@{ Content = '{"login":"lazy-org"}' }
            }
        }

        It 'Lazy-loads config and resolves org when MaesterConfig is null and no -Organization supplied' {
            Connect-MtGitHub

            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected    | Should -BeTrue
                $__MtSession.GitHubConnection.Organization | Should -Be 'lazy-org'
                # $__MtSession.MaesterConfig is now set; real Get-MtMaesterConfigGlobalSetting reads it
                $__MtSession.MaesterConfig.GlobalSettings.GitHubOrganization | Should -Be 'lazy-org'
            }
        }

        It 'Lazy-loads config for ApiBaseUri and ApiVersion when -Organization is supplied but others are omitted' {
            Connect-MtGitHub -Organization 'myorg'

            InModuleScope Maester {
                $__MtSession.GitHubConnection.Connected  | Should -BeTrue
                $__MtSession.GitHubConnection.ApiBaseUri | Should -Be 'https://api.lazy.ghe.com'
                $__MtSession.GitHubConnection.ApiVersion | Should -Be '2024-06-01'
            }
        }

        It 'All three config-backed values (org, ApiBaseUri, ApiVersion) are resolved from lazy-loaded config' {
            Connect-MtGitHub

            InModuleScope Maester {
                $conn = $__MtSession.GitHubConnection
                $conn.Organization | Should -Be 'lazy-org'
                $conn.ApiBaseUri   | Should -Be 'https://api.lazy.ghe.com'
                $conn.ApiVersion   | Should -Be '2024-06-01'
            }
        }
    }
}
