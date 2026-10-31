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
        Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
            [pscustomobject]@{
                Assignments     = @(
                    [pscustomobject]@{
                        roleDefinitionId = '00000000-0000-0000-0000-000000000001'
                        principal        = [pscustomobject]@{ id = 'licensed-admin'; '@odata.type' = '#microsoft.graph.user' }
                    }
                )
                EligibleChecked = $false
            }
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
        Should -Invoke Get-MtDirectoryRoleAssignment -ModuleName Maester -Exactly 1 -ParameterFilter {
            $MemberStatus -eq 'Active' -and $ExpandPrincipal
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

    Context 'role assigned to a group' {
        BeforeEach {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                [pscustomobject]@{
                    Assignments     = @(
                        [pscustomobject]@{
                            roleDefinitionId = '00000000-0000-0000-0000-000000000002'
                            principal        = [pscustomobject]@{ id = 'admin-group'; '@odata.type' = '#microsoft.graph.group' }
                        }
                    )
                    EligibleChecked = $false
                }
            }
        }

        It 'evaluates the members of a role-assigned group' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                [pscustomobject]@{ id = 'licensed-admin'; '@odata.type' = '#microsoft.graph.user' }
            } -ParameterFilter { $RelativeUri -eq 'groups/admin-group/members' }

            InModuleScope Maester {
                Test-MtCisAdminLicenseFootprint | Should -BeFalse
            }

            Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter {
                $RelativeUri -eq 'users' -and $UniqueId -contains 'licensed-admin'
            }
        }

        It 'errors when the members of a role-assigned group cannot be read' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Forbidden)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Forbidden', $response)
            } -ParameterFilter { $RelativeUri -eq 'groups/admin-group/members' }

            InModuleScope Maester {
                { Test-MtCisAdminLicenseFootprint } | Should -Throw '*Could not read the members of role-assigned group admin-group*'
            }
        }

        It 'skips a role-assigned group that no longer exists' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Not Found', $response)
            } -ParameterFilter { $RelativeUri -eq 'groups/admin-group/members' }

            InModuleScope Maester {
                Test-MtCisAdminLicenseFootprint | Should -BeTrue
            }
        }
    }
}
