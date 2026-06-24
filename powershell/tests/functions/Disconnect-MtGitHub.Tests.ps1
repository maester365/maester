BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Disconnect-MtGitHub' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache      = @{}
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache      = @{}
        }
    }

    Context 'When GitHub state is set' {
        It 'Clears GitHubConnection, GitHubAuthHeader, and GitHubCache' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer token' }
                $__MtSession.GitHubCache      = @{ 'foo' = 'bar' }
            }
            Disconnect-MtGitHub 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
                $__MtSession.GitHubCache.Count | Should -Be 0
            }
        }
    }

    Context 'When GitHub state is already null' {
        It 'Does not throw' {
            { Disconnect-MtGitHub 6>$null } | Should -Not -Throw
        }

        It 'Leaves session keys null' {
            Disconnect-MtGitHub 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }
    }
}
