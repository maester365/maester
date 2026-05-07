BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Clear-ModuleVariable — GitHub session lifecycle' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $true; Organization = 'myorg' }
            $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer testtoken' }
            $__MtSession.GitHubCache      = @{ somekey = 'cached-value' }
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache      = @{}
        }
    }

    It 'Preserves GitHubConnection after Clear-ModuleVariable' {
        InModuleScope Maester {
            Clear-ModuleVariable
            $__MtSession.GitHubConnection | Should -Not -BeNullOrEmpty
            $__MtSession.GitHubConnection.Connected | Should -BeTrue
        }
    }

    It 'Preserves GitHubAuthHeader after Clear-ModuleVariable' {
        InModuleScope Maester {
            Clear-ModuleVariable
            $__MtSession.GitHubAuthHeader | Should -Not -BeNullOrEmpty
            $__MtSession.GitHubAuthHeader['Authorization'] | Should -Be 'Bearer testtoken'
        }
    }

    It 'Resets GitHubCache to empty after Clear-ModuleVariable' {
        InModuleScope Maester {
            Clear-ModuleVariable
            $__MtSession.GitHubCache.Count | Should -Be 0
        }
    }

    It 'Test-MtConnection GitHub still returns True after Clear-ModuleVariable' {
        InModuleScope Maester {
            Clear-ModuleVariable
            Test-MtConnection -Service GitHub | Should -BeTrue
        }
    }
}
