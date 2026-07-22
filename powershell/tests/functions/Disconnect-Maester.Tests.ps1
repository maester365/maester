BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Disconnect-Maester - GitHub session lifecycle' {
    BeforeEach {
        Mock Disconnect-MgGraph -ModuleName Maester {}

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
        It 'clears GitHub session state' {
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

    Context 'Module-qualified invocation (Maester\Disconnect-Maester)' {
        It 'clears GitHub session state' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer token' }
                $__MtSession.GitHubCache      = @{ 'foo' = 'bar' }
            }
            Maester\Disconnect-Maester 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
                $__MtSession.GitHubCache.Count | Should -Be 0
            }
        }
    }

    Context 'Disconnect-MtMaester alias' {
        It 'clears GitHub session state' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
                $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer token' }
                $__MtSession.GitHubCache      = @{ 'foo' = 'bar' }
            }
            Disconnect-MtMaester 6>$null
            InModuleScope Maester {
                $__MtSession.GitHubConnection | Should -BeNullOrEmpty
                $__MtSession.GitHubAuthHeader | Should -BeNullOrEmpty
                $__MtSession.GitHubCache.Count | Should -Be 0
            }
        }
    }

    Context 'Disconnect-MtGraph alias' {
        It 'does not clear GitHub session state' {
            InModuleScope Maester {
                $__MtSession.Connections      = @('GitHub')
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

Describe 'Disconnect-Maester - Active Directory session lifecycle' {
    BeforeEach {
        Mock Disconnect-MgGraph -ModuleName Maester {}

        InModuleScope Maester {
            $__MtSession.Connections = @()
            $__MtSession.ADConnection = [PSCustomObject]@{
                Connected        = $true
                DomainController = 'dc01.contoso.com'
            }
            $__MtSession.ADCache = @{ DomainState = [PSCustomObject]@{ Domain = 'contoso.com' } }
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.Connections = @()
            $__MtSession.ADConnection = $null
            $__MtSession.ADCache = @{}
        }
    }

    It 'Clears Active Directory state even if another Connect-Maester call replaced the service list' {
        InModuleScope Maester {
            $__MtSession.Connections = @('Graph')
        }

        Disconnect-Maester 6>$null

        InModuleScope Maester {
            $__MtSession.ADConnection | Should -BeNullOrEmpty
            $__MtSession.ADCache.Count | Should -Be 0
        }
    }

    It 'Preserves Active Directory state when only Disconnect-MtGraph is requested' {
        Disconnect-MtGraph 6>$null

        InModuleScope Maester {
            $__MtSession.ADConnection.Connected | Should -BeTrue
            $__MtSession.ADCache.Count | Should -Be 1
        }
    }
}
