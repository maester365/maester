BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
}

Describe 'Test-MtConnection AzureDevOps cache' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.AzureDevOpsConnectionCache = $null
            $__MtSession.Remove('AzureDevOpsConnection')
        }
    }

    AfterEach {
        Remove-Item -Path function:global:Get-ADOPSConnection -ErrorAction SilentlyContinue
        InModuleScope Maester {
            $__MtSession.AzureDevOpsConnectionCache = $null
            $__MtSession.Remove('AzureDevOpsConnection')
        }
    }

    It 'caches a successful Azure DevOps probe under a cache-specific key' {
        Set-Item -Path function:global:Get-ADOPSConnection -Value { @{ Organization = 'ado-org' } }

        $result = Test-MtConnection -Service AzureDevOps -Details

        $result.AllConnected | Should -BeTrue
        $result.AzureDevOps['Organization'] | Should -Be 'ado-org'
        InModuleScope Maester {
            $__MtSession.AzureDevOpsConnectionCache['Organization'] | Should -Be 'ado-org'
            $__MtSession.ContainsKey('AzureDevOpsConnection') | Should -BeFalse
        }
    }

    It 'caches a failed Azure DevOps probe as NotConnected' {
        Set-Item -Path function:global:Get-ADOPSConnection -Value { $null }

        $result = Test-MtConnection -Service AzureDevOps -Details

        $result.AllConnected | Should -BeFalse
        $result.AzureDevOps | Should -BeNullOrEmpty
        InModuleScope Maester {
            $__MtSession.AzureDevOpsConnectionCache | Should -Be 'NotConnected'
            $__MtSession.ContainsKey('AzureDevOpsConnection') | Should -BeFalse
        }
    }

    It 'uses the cached Azure DevOps probe result without re-querying the external command' {
        InModuleScope Maester {
            $__MtSession.AzureDevOpsConnectionCache = @{ Organization = 'cached-org' }
        }
        Set-Item -Path function:global:Get-ADOPSConnection -Value { throw 'Get-ADOPSConnection should not be called when cache exists.' }

        $result = Test-MtConnection -Service AzureDevOps -Details

        $result.AllConnected | Should -BeTrue
        $result.AzureDevOps['Organization'] | Should -Be 'cached-org'
    }

    It 'clears the Azure DevOps probe cache during module-variable reset' {
        InModuleScope Maester {
            $__MtSession.AzureDevOpsConnectionCache = @{ Organization = 'cached-org' }

            Clear-ModuleVariable

            $__MtSession.AzureDevOpsConnectionCache | Should -BeNullOrEmpty
            $__MtSession.ContainsKey('AzureDevOpsConnection') | Should -BeFalse
        }
    }
}
