BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    # Bypass Pester's slow command-resolution path when MS service modules are not loaded
    # in the test environment. Track which stubs we created so AfterAll cleans up only
    # those — never touch real cmdlets that were already present.
    $script:createdStubs = @()
    foreach ($cmd in 'Get-AzContext','Invoke-AzRestMethod','Get-MgContext','Get-CsTenant','Get-PnPConnection') {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            New-Item -Path "function:global:$cmd" -Value { } | Out-Null
            $script:createdStubs += $cmd
        }
    }
}

AfterAll {
    foreach ($cmd in $script:createdStubs) {
        Remove-Item -Path "function:global:$cmd" -ErrorAction SilentlyContinue
    }
}

Describe 'Test-MtConnection — GitHub service' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection      = $null
            $__MtSession.AzureDevOpsConnection = $null
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection      = $null
            $__MtSession.AzureDevOpsConnection = $null
        }
    }

    Context 'When Connect-MtGitHub has never been called' {
        It 'Returns $false for -Service GitHub' {
            InModuleScope Maester {
                Test-MtConnection -Service GitHub | Should -BeFalse
            }
        }

        It 'Writes the NotCalled sentinel to GitHubConnection' {
            InModuleScope Maester {
                Test-MtConnection -Service GitHub | Out-Null
                $__MtSession.GitHubConnection | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubConnection.FailureReason | Should -Be 'NotCalled'
            }
        }
    }

    Context 'When GitHub is explicitly disconnected' {
        It 'Returns $false when Connected is $false' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'TokenInvalid' }
                Test-MtConnection -Service GitHub | Should -BeFalse
            }
        }

        It 'Returns $false when membership is pending (FailureReason = OrgMembershipPending)' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'OrgMembershipPending' }
                Test-MtConnection -Service GitHub | Should -BeFalse
            }
        }
    }

    Context 'When GitHub is connected' {
        It 'Returns $true' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                Test-MtConnection -Service GitHub | Should -BeTrue
            }
        }

        It 'Returns an object with GitHub populated and AllConnected $true when using -Details' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $result = Test-MtConnection -Service GitHub -Details
                $result.GitHub | Should -Not -BeNullOrEmpty
                $result.GitHub.Connected | Should -BeTrue
                $result.AllConnected | Should -BeTrue
            }
        }
    }

    Context 'When GitHub is not connected' {
        It 'Returns an object with GitHub $null and AllConnected $false when using -Details' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'NoToken' }
                $result = Test-MtConnection -Service GitHub -Details
                $result.GitHub | Should -BeNullOrEmpty
                $result.AllConnected | Should -BeFalse
            }
        }
    }

    Context '-Service GitHub -Details with GitHub connected' {
        It 'Populates the GitHub property and returns AllConnected $true' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
            }
            $result = Test-MtConnection -Service GitHub -Details
            $result.GitHub | Should -Not -BeNullOrEmpty
            $result.GitHub.Connected | Should -BeTrue
            $result.AllConnected | Should -BeTrue
        }
    }

    Context '-Service All - GitHub is not included' {
        It 'Returns AllConnected $true when all included services are connected and GitHub session is absent' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection      = $null
                $__MtSession.AzureDevOpsConnection = [PSCustomObject]@{ Organization = 'ado-org' }
            }
            Mock Get-AzContext { [PSCustomObject]@{ Account = 'test@contoso.com' } } -ModuleName Maester
            Mock Invoke-AzRestMethod { [PSCustomObject]@{} } -ModuleName Maester
            Mock Get-MgContext { [PSCustomObject]@{ TenantId = 'tenant-id' } } -ModuleName Maester
            Mock Get-MtExo {
                @(
                    [PSCustomObject]@{ Name = 'ExchangeOnline'; State = 'Connected'; IsEopSession = $false }
                    [PSCustomObject]@{ Name = 'ExchangeOnline'; State = 'Connected'; IsEopSession = $true }
                )
            } -ModuleName Maester
            Mock Get-CsTenant { [PSCustomObject]@{ TenantId = 'tenant-id' } } -ModuleName Maester
            Mock Get-PnPConnection { [PSCustomObject]@{ Url = 'https://contoso.sharepoint.com' } } -ModuleName Maester
            $result = Test-MtConnection -Service All -Details
            $result.AllConnected | Should -BeTrue
            $result.GitHub | Should -BeNullOrEmpty
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -BeNullOrEmpty
            }
        }
    }

    Context '-Service All - GitHub NotCalled sentinel is ignored' {
        It 'does not set the GitHub details property' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection      = [PSCustomObject]@{ Connected = $false; FailureReason = 'NotCalled' }
                $__MtSession.AzureDevOpsConnection = 'NotConnected'
            }
            Mock Get-AzContext { $null } -ModuleName Maester
            Mock Get-MgContext { $null } -ModuleName Maester
            Mock Get-MtExo { $null } -ModuleName Maester
            Mock Get-CsTenant { $null } -ModuleName Maester
            $result = Test-MtConnection -Service All -Details
            $result.AllConnected | Should -BeFalse
            $result.GitHub | Should -BeNullOrEmpty
        }
    }

    Context '-Service GitHub -Details formatted output' {
        It 'Renders safe GitHub metadata and excludes auth/token values' {
            $fakeToken = 'ghp_FAKE_TOKEN_VALUE_DO_NOT_USE'
            InModuleScope Maester -ArgumentList $fakeToken {
                param($FakeToken)
                $__MtSession.GitHubConnection = [PSCustomObject]@{
                    Connected                        = $true
                    Organization                     = 'myorg'
                    TokenLogin                       = 'octocat'
                    ApiBaseUri                       = 'https://api.github.com'
                    ApiVersion                       = '2022-11-28'
                    Role                             = 'admin'
                    RoleState                        = 'active'
                    AdministrationPermissionVerified = $true
                }
                $__MtSession.GitHubAuthHeader = @{
                    Authorization = "Bearer $FakeToken"
                }
            }
            $rendered = Test-MtConnection -Service GitHub -Details | Out-String
            $rendered | Should -Match 'GitHub'
            $rendered | Should -Match 'myorg'
            $rendered | Should -Match 'octocat'
            $rendered | Should -Not -Match 'Bearer'
            $rendered | Should -Not -Match 'Authorization'
            $rendered | Should -Not -Match ([regex]::Escape($fakeToken))
        }
    }

    Context '-Service All — GitHub connected session is ignored' {
        It 'Does not populate the GitHub property' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection      = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.AzureDevOpsConnection = 'NotConnected'
            }
            Mock Get-AzContext { $null } -ModuleName Maester
            Mock Get-MgContext { $null } -ModuleName Maester
            Mock Get-MtExo { $null } -ModuleName Maester
            Mock Get-CsTenant { $null } -ModuleName Maester
            $result = Test-MtConnection -Service All -Details
            $result.GitHub | Should -BeNullOrEmpty
        }
    }
}
