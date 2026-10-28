BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
}

Describe 'Test-MtCisAdminLicenseFootprint' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName Maester Get-MgContext {
            [pscustomobject]@{ AuthType = 'Delegated' }
        }
        Mock -ModuleName Maester Get-MtRole {
            @(
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000001'; displayName = 'Global Administrator' }
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000002'; displayName = 'Exchange Administrator' }
            )
        }
        Mock -ModuleName Maester Get-MtRoleMember {
            [pscustomobject]@{ id = 'licensed-admin'; '@odata.type' = '#microsoft.graph.user' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ id = 'licensed-admin'; displayName = 'Licensed Admin'; userPrincipalName = 'admin@example.com' }
        } -ParameterFilter { $RelativeUri -eq 'users' }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ skuPartNumber = 'ENTERPRISEPREMIUM' }
        } -ParameterFilter { $RelativeUri -like 'users/*/licenseDetails' }
        Mock -ModuleName Maester Add-MtTestResultDetail { }
    }

    It 'fails when a permanently assigned administrator has a non-approved license SKU' {
        InModuleScope Maester {
            Test-MtCisAdminLicenseFootprint | Should -BeFalse
        }

        Should -Invoke Get-MtRoleMember -ModuleName Maester -Exactly 1 -ParameterFilter {
            $MemberStatus -eq 'Active'
        }
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter {
            $RelativeUri -like 'users/*/licenseDetails'
        }
    }

    It 'passes when an administrator has an approved Entra P1 license' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ skuPartNumber = 'AAD_PREMIUM' }
        } -ParameterFilter { $RelativeUri -like 'users/*/licenseDetails' }

        InModuleScope Maester {
            Test-MtCisAdminLicenseFootprint | Should -BeTrue
        }
    }

    It 'allows another verified identity-only SKU through the parameter' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ skuPartNumber = 'IDENTITY_ONLY_SKU' }
        } -ParameterFilter { $RelativeUri -like 'users/*/licenseDetails' }

        InModuleScope Maester {
            Test-MtCisAdminLicenseFootprint -AllowedLicenseSkuPartNumbers 'IDENTITY_ONLY_SKU' | Should -BeTrue
        }
    }
}
