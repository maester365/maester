BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Get-MtPrincipalPrivilegedRole
}

Describe 'Get-MtPrincipalPrivilegedRole' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{ id = 'role-ga'; displayName = 'Global Administrator' },
                [pscustomobject]@{ id = 'role-dr'; displayName = 'Directory Readers' }
            )
        } -ParameterFilter { $RelativeUri -eq 'roleManagement/directory/roleDefinitions' }

        Mock -ModuleName Maester Get-MtRoleInfo {
            return [pscustomobject]@{ IsPrivileged = ($RoleName -eq 'GlobalAdministrator') }
        }
    }

    It 'returns an active privileged role held by a requested principal' {
        Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
            return [pscustomobject]@{
                Assignments     = @([pscustomobject]@{ principalId = 'p-1'; roleDefinitionId = 'role-ga'; AssignmentType = 'Active' })
                EligibleChecked = $true
            }
        }

        $result = Get-MtPrincipalPrivilegedRole -PrincipalId 'p-1'

        @($result.RolesByPrincipal['p-1']) | Should -Be @('Global Administrator')
        $result.EligibleChecked | Should -BeTrue
    }

    It 'marks a PIM-eligible privileged role as eligible' {
        Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
            return [pscustomobject]@{
                Assignments     = @([pscustomobject]@{ principalId = 'p-1'; roleDefinitionId = 'role-ga'; AssignmentType = 'Eligible' })
                EligibleChecked = $true
            }
        }

        $result = Get-MtPrincipalPrivilegedRole -PrincipalId 'p-1'

        @($result.RolesByPrincipal['p-1']) | Should -Be @('Global Administrator (eligible)')
    }

    It 'ignores principals that were not requested, even when they hold a privileged role' {
        Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
            return [pscustomobject]@{
                Assignments     = @(
                    [pscustomobject]@{ principalId = 'p-1'; roleDefinitionId = 'role-ga'; AssignmentType = 'Active' },
                    [pscustomobject]@{ principalId = 'someone-else'; roleDefinitionId = 'role-ga'; AssignmentType = 'Active' }
                )
                EligibleChecked = $true
            }
        }

        $result = Get-MtPrincipalPrivilegedRole -PrincipalId 'p-1'

        @($result.RolesByPrincipal.Keys) | Should -Be @('p-1')
    }

    It 'ignores a role that is not privileged' {
        Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
            return [pscustomobject]@{
                Assignments     = @([pscustomobject]@{ principalId = 'p-1'; roleDefinitionId = 'role-dr'; AssignmentType = 'Active' })
                EligibleChecked = $true
            }
        }

        $result = Get-MtPrincipalPrivilegedRole -PrincipalId 'p-1'

        $result.RolesByPrincipal.Count | Should -Be 0
    }

    It 'reports when PIM-eligible assignments were not checked' {
        Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
            return [pscustomobject]@{ Assignments = @(); EligibleChecked = $false }
        }

        $result = Get-MtPrincipalPrivilegedRole -PrincipalId 'p-1'

        $result.EligibleChecked | Should -BeFalse
    }

    It 'lets a failure to read role assignments throw, so the caller can report it' {
        Mock -ModuleName Maester Get-MtDirectoryRoleAssignment { throw '403 Forbidden' }

        { Get-MtPrincipalPrivilegedRole -PrincipalId 'p-1' } | Should -Throw '*403*'
    }
}
