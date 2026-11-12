Describe 'Test-MtVaultSoftDelete' -Tag 'Unit' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Test-MtVaultSoftDelete

        Mock -ModuleName Maester Invoke-MtAzureResourceGraphRequest { $script:Vaults }
        Mock -ModuleName Maester Invoke-MtAzureRequest { $script:VaultConfig }
        Mock -ModuleName Maester Add-MtTestResultDetail {}
    }

    BeforeEach {
        $script:Vaults = @(
            [pscustomobject]@{
                name           = 'vault-one'
                resourceGroup  = 'backup-rg'
                subscriptionId = 'offline-subscription'
            }
        )
        $script:VaultConfig = [pscustomobject]@{
            properties = [pscustomobject]@{
                enhancedSecurityState  = 'Enabled'
                softDeleteFeatureState = 'Enabled'
            }
        }
    }

    It 'returns <Expected> for soft delete <SoftDelete> and enhanced security <EnhancedSecurity>' -ForEach @(
        @{ SoftDelete = 'Disabled'; EnhancedSecurity = 'Enabled'; Expected = $false }
        @{ SoftDelete = 'Enabled'; EnhancedSecurity = 'Disabled'; Expected = $true }
        @{ SoftDelete = 'AlwaysON'; EnhancedSecurity = 'Disabled'; Expected = $true }
        @{ SoftDelete = 'AlwaysON'; EnhancedSecurity = 'AlwaysON'; Expected = $true }
        @{ SoftDelete = 'Invalid'; EnhancedSecurity = 'Enabled'; Expected = $false }
        @{ SoftDelete = 'Enabled'; EnhancedSecurity = 'Enabled'; Expected = $true }
    ) {
        $script:VaultConfig.properties.softDeleteFeatureState = $SoftDelete
        $script:VaultConfig.properties.enhancedSecurityState = $EnhancedSecurity

        Test-MtVaultSoftDelete | Should -Be $Expected

        if (-not $Expected) {
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Result -like "*state: $SoftDelete*"
            }
        }
    }

    It 'fails with Unknown when the soft delete property is missing' {
        $script:VaultConfig.properties.PSObject.Properties.Remove('softDeleteFeatureState')

        Test-MtVaultSoftDelete | Should -BeFalse

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -like '*state: Unknown*'
        }
    }

    It 'passes without reading vault configuration when there are no vaults' {
        $script:Vaults = @()

        Test-MtVaultSoftDelete | Should -BeTrue

        Should -Invoke Invoke-MtAzureRequest -ModuleName Maester -Times 0 -Exactly
    }

    It 'fails when one vault has soft delete disabled' {
        $script:Vaults += [pscustomobject]@{
            name           = 'vault-two'
            resourceGroup  = 'backup-rg'
            subscriptionId = 'offline-subscription'
        }
        Mock -ModuleName Maester Invoke-MtAzureRequest {
            [pscustomobject]@{
                properties = [pscustomobject]@{
                    enhancedSecurityState  = 'Enabled'
                    softDeleteFeatureState = 'Disabled'
                }
            }
        } -ParameterFilter { $RelativeUri -like '*/vault-two/*' }

        Test-MtVaultSoftDelete | Should -BeFalse
    }
}
