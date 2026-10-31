BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
}

Describe 'Test-MtCisAdminLicenseFootprint' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName Maester Get-MgContext {
            [pscustomobject]@{ AuthType = 'Application' }
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
            [pscustomobject]@{
                id                 = 'licensed-admin'
                displayName        = 'Licensed Admin'
                userPrincipalName  = 'admin@example.com'
                assignedLicenses   = @([pscustomobject]@{ skuId = 'unapproved-sku' })
            }
        } -ParameterFilter { $RelativeUri -eq 'users' }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ skuId = 'unapproved-sku'; skuPartNumber = 'ENTERPRISEPREMIUM' }
        } -ParameterFilter { $RelativeUri -eq 'subscribedSkus' }
        Mock -ModuleName Maester Add-MtTestResultDetail { }
    }

    It 'checks assigned licenses in application authentication context' {
        InModuleScope Maester {
            Test-MtCisAdminLicenseFootprint | Should -BeFalse
        }

        Should -Not -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter {
            $SkippedBecause -eq 'NotSupportedAppPermission'
        }
        Should -Invoke Get-MtRoleMember -ModuleName Maester -Exactly 1 -ParameterFilter {
            $MemberStatus -eq 'Active'
        }
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter {
            $RelativeUri -eq 'users' -and $Select -contains 'assignedLicenses'
        }
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter {
            $RelativeUri -eq 'subscribedSkus'
        }
        Should -Not -Invoke Invoke-MtGraphRequest -ModuleName Maester -ParameterFilter {
            $RelativeUri -like 'users/*/licenseDetails'
        }
    }

    It 'passes when an administrator has an approved Entra P1 license' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{
                id                = 'licensed-admin'
                displayName       = 'Licensed Admin'
                userPrincipalName = 'admin@example.com'
                assignedLicenses  = @([pscustomobject]@{ skuId = 'p1-sku' })
            }
        } -ParameterFilter { $RelativeUri -eq 'users' }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ skuId = 'p1-sku'; skuPartNumber = 'AAD_PREMIUM' }
        } -ParameterFilter { $RelativeUri -eq 'subscribedSkus' }

        InModuleScope Maester {
            Test-MtCisAdminLicenseFootprint | Should -BeTrue
        }
    }

    It 'allows another verified identity-only SKU through the parameter' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{
                id                = 'licensed-admin'
                displayName       = 'Licensed Admin'
                userPrincipalName = 'admin@example.com'
                assignedLicenses  = @([pscustomobject]@{ skuId = 'custom-sku' })
            }
        } -ParameterFilter { $RelativeUri -eq 'users' }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ skuId = 'custom-sku'; skuPartNumber = 'IDENTITY_ONLY_SKU' }
        } -ParameterFilter { $RelativeUri -eq 'subscribedSkus' }

        InModuleScope Maester {
            Test-MtCisAdminLicenseFootprint -AllowedLicenseSkuPartNumbers 'IDENTITY_ONLY_SKU' | Should -BeTrue
        }
    }

    It 'errors when Graph omits an active administrator from the user details response' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{
                id                = 'different-user'
                displayName       = 'Different User'
                userPrincipalName = 'different@example.com'
                assignedLicenses  = @()
            }
        } -ParameterFilter { $RelativeUri -eq 'users' }

        InModuleScope Maester {
            { Test-MtCisAdminLicenseFootprint } | Should -Throw '*did not return user details*'
        }
    }
}

Describe 'Test-MtCisAdminLicenseFootprint role-assigned groups' -Tag 'Unit' {
    BeforeAll {
        function Get-HttpError ([int]$StatusCode) {
            $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$StatusCode)
            [Microsoft.PowerShell.Commands.HttpResponseException]::new("Response status code does not indicate success: $StatusCode.", $response)
        }
    }

    BeforeEach {
        Mock -ModuleName Maester Get-MtRole {
            [pscustomobject]@{ id = '62e90394-69f5-4237-9190-012177145e10'; displayName = 'Global Administrator' }
        }
        Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
            [pscustomobject]@{
                Assignments = @([pscustomobject]@{
                        roleDefinitionId = '62e90394-69f5-4237-9190-012177145e10'
                        AssignmentType   = 'Active'
                        principal        = [pscustomobject]@{ id = '33333333-3333-3333-3333-333333333333'; '@odata.type' = '#microsoft.graph.group' }
                    })
            }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw (Get-HttpError 403) } -ParameterFilter { $RelativeUri -like 'groups/*/members' }
        Mock -ModuleName Maester Invoke-MtGraphRequest { }
        Mock -ModuleName Maester Add-MtTestResultDetail { }
    }

    It 'errors when the members of a role-assigned group cannot be read' {
        InModuleScope Maester {
            { Test-MtCisAdminLicenseFootprint } | Should -Throw '*Could not read the members of group (33333333-3333-3333-3333-333333333333)*403*'
        }

        Should -Invoke Get-MtDirectoryRoleAssignment -ModuleName Maester -Exactly 1 -ParameterFilter { $MemberStatus -eq 'Active' }
        Should -Not -Invoke Invoke-MtGraphRequest -ModuleName Maester -ParameterFilter { $RelativeUri -eq 'users' }
        Should -Not -Invoke Add-MtTestResultDetail -ModuleName Maester
    }
}
