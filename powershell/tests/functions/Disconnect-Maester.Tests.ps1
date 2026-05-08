BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Disconnect-Maester — GitHub cleanup branch' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.Connections      = @()
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache      = @{}
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.Connections      = @()
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache      = @{}
        }
    }

    Context 'Default name (Disconnect-Maester)' {
        It 'Clears all three GitHub session keys' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer token' }
                $__MtSession.GitHubCache      = @{ 'foo' = 'bar' }
            }
            Disconnect-Maester 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
                $__MtSession.GitHubCache.Count | Should -Be 0
            }
        }
    }

    Context 'Disconnect-MtMaester alias' {
        It 'Clears GitHub state' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer token' }
            }
            Disconnect-MtMaester 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Disconnect-MtGraph alias' {
        It 'Does NOT clear GitHub state (Graph-only semantic)' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer token' }
            }
            Disconnect-MtGraph 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubConnection.Organization | Should -Be 'myorg'
                $__MtSession.GitHubAuthHeader | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader['Authorization'] | Should -Be 'Bearer token'
            }
        }
    }

    Context 'When no GitHub state exists' {
        It 'Produces no GitHub-related host output' {
            $hostOutput = Disconnect-Maester 6>&1 | Out-String
            $hostOutput | Should -Not -Match 'Disconnected from GitHub'
        }
    }
}
