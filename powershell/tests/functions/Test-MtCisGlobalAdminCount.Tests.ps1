BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
}

Describe 'Test-MtCisGlobalAdminCount' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName Maester Get-MtRole {
            @(
                [pscustomobject]@{ id = '62e90394-69f5-4237-9190-012177145e10'; displayName = 'Global Administrator' }
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000001'; displayName = 'Exchange Administrator' }
            )
        }
        Mock -ModuleName Maester Add-MtTestResultDetail { }
    }

    It 'counts unique users assigned directly or through a role-assigned group' {
        Mock -ModuleName Maester Get-MtDirectoryRoleMember {
            [pscustomobject]@{ id = 'admin-1'; '@odata.type' = '#microsoft.graph.user' }
            [pscustomobject]@{ id = 'admin-2'; '@odata.type' = '#microsoft.graph.user' }
            [pscustomobject]@{ id = 'admin-1'; '@odata.type' = '#microsoft.graph.user' }
            [pscustomobject]@{ id = 'app-1'; '@odata.type' = '#microsoft.graph.servicePrincipal' }
        }

        InModuleScope Maester {
            Test-MtCisGlobalAdminCount | Should -BeTrue
        }

        Should -Invoke Get-MtDirectoryRoleMember -ModuleName Maester -Exactly 1 -ParameterFilter {
            (@($RoleId | ForEach-Object { "$_" }) -join ',') -eq '62e90394-69f5-4237-9190-012177145e10'
        }
    }

    It 'fails with <Count> Global Administrators' -ForEach @(
        @{ Count = 1 }
        @{ Count = 5 }
    ) {
        Mock -ModuleName Maester Get-MtDirectoryRoleMember {
            1..$Count | ForEach-Object { [pscustomobject]@{ id = "admin-$_"; '@odata.type' = '#microsoft.graph.user' } }
        }.GetNewClosure()

        InModuleScope Maester {
            Test-MtCisGlobalAdminCount | Should -BeFalse
        }
    }

    It 'errors when the members of a role-assigned group cannot be read' {
        Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
            [pscustomobject]@{
                Assignments     = @(
                    [pscustomobject]@{
                        roleDefinitionId = '62e90394-69f5-4237-9190-012177145e10'
                        principal        = [pscustomobject]@{ id = 'admin-group'; '@odata.type' = '#microsoft.graph.group' }
                    }
                )
                EligibleChecked = $false
            }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Forbidden)
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Forbidden', $response)
        } -ParameterFilter { $RelativeUri -eq 'groups/admin-group/members' }

        InModuleScope Maester {
            { Test-MtCisGlobalAdminCount } | Should -Throw '*Could not read the members of role-assigned group admin-group*'
        }
    }
}
