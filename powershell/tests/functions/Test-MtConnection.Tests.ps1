BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Test-MtConnection — GitHub service' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
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

    Context '-Service All -Details with GitHub connected' {
        It 'Populates the GitHub property even when other services are absent' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                # Other services (Azure, Graph, etc.) are not connected in unit test scope.
                # AllConnected will be $false due to missing services, but GitHub must be set.
                $result = Test-MtConnection -Service All -Details
                $result.GitHub | Should -Not -BeNullOrEmpty
                $result.GitHub.Connected | Should -BeTrue
                # AllConnected reflects ALL services; other services will be absent here
                $result.AllConnected | Should -BeFalse
            }
        }
    }
}
