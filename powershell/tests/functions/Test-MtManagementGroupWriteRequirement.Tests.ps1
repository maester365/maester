BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtManagementGroupWriteRequirement
}

Describe 'Test-MtManagementGroupWriteRequirement' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName Maester Add-MtTestResultDetail {}
        Mock -ModuleName Maester Get-MtAzureManagementGroup {
            [pscustomobject]@{
                id         = '/providers/Microsoft.Management/managementGroups/tenant-1'
                name       = 'tenant-1'
                properties = [pscustomobject]@{ tenantid = 'tenant-1' }
            }
        }
    }

    It 'passes when the setting requires write permissions' {
        Mock -ModuleName Maester Invoke-MtAzureRequest {
            [pscustomobject]@{ properties = [pscustomobject]@{ requireAuthorizationForGroupCreation = $true } }
        }

        Test-MtManagementGroupWriteRequirement | Should -BeTrue
    }

    It 'fails when the setting does not require write permissions' {
        Mock -ModuleName Maester Invoke-MtAzureRequest {
            [pscustomobject]@{ properties = [pscustomobject]@{ requireAuthorizationForGroupCreation = $false } }
        }

        Test-MtManagementGroupWriteRequirement | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Result -like '*Anyone in the tenant may create them*' }
    }

    It 'skips as not authorized when reading the setting is denied, instead of reporting a failure' {
        Mock -ModuleName Maester Invoke-MtAzureRequest { $null }

        Test-MtManagementGroupWriteRequirement | Should -BeNullOrEmpty

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 0 -Exactly -ParameterFilter { $Result -like '*Anyone in the tenant may create them*' }
    }

    It 'skips when the tenant root management group cannot be read' {
        Mock -ModuleName Maester Get-MtAzureManagementGroup { $null }
        Mock -ModuleName Maester Invoke-MtAzureRequest { throw 'must not be called' }

        Test-MtManagementGroupWriteRequirement | Should -BeNullOrEmpty

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $SkippedCustomReason -eq 'Tenant Root Group not found' }
    }
}
