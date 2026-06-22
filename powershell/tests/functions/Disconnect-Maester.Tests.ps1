BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Disconnect-Maester - GitHub session lifecycle' {
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
        It 'does not clear GitHub session state' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer token' }
                $__MtSession.GitHubCache      = @{ 'foo' = 'bar' }
            }
            Disconnect-Maester 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubConnection.Organization | Should -Be 'myorg'
                $__MtSession.GitHubAuthHeader | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader['Authorization'] | Should -Be 'Bearer token'
                $__MtSession.GitHubCache['foo'] | Should -Be 'bar'
            }
        }
    }

    Context 'Module-qualified invocation (Maester\Disconnect-Maester)' {
        It 'does not clear GitHub session state' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer token' }
                $__MtSession.GitHubCache      = @{ 'foo' = 'bar' }
            }
            Maester\Disconnect-Maester 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubConnection.Organization | Should -Be 'myorg'
                $__MtSession.GitHubAuthHeader | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader['Authorization'] | Should -Be 'Bearer token'
                $__MtSession.GitHubCache['foo'] | Should -Be 'bar'
            }
        }
    }

    Context 'Disconnect-MtMaester alias' {
        It 'does not clear GitHub session state' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer token' }
                $__MtSession.GitHubCache      = @{ 'foo' = 'bar' }
            }
            Disconnect-MtMaester 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubConnection.Organization | Should -Be 'myorg'
                $__MtSession.GitHubAuthHeader | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader['Authorization'] | Should -Be 'Bearer token'
                $__MtSession.GitHubCache['foo'] | Should -Be 'bar'
            }
        }
    }

    Context 'Disconnect-MtGraph alias' {
        It 'does not clear GitHub session state' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer token' }
                $__MtSession.GitHubCache      = @{ 'foo' = 'bar' }
            }
            Disconnect-MtGraph 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubConnection.Organization | Should -Be 'myorg'
                $__MtSession.GitHubAuthHeader | Should -Not -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader['Authorization'] | Should -Be 'Bearer token'
                $__MtSession.GitHubCache['foo'] | Should -Be 'bar'
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
