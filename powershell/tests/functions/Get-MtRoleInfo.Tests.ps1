BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
}

Describe 'Get-MtRoleInfo' -Tag 'Unit' {
    Context 'role table resilience' {
        # Regression test for the MT.1020 (Test-MtCaExclusionForDirectorySyncAccount)
        # failure: under Invoke-Maester the module-load-time assignment of
        # $script:MtRoles did not persist into the Pester test-execution context, so
        # Get-MtRoleInfo threw "You cannot call a method on a null-valued expression"
        # at $script:MtRoles.ContainsKey(). The fix builds the tables lazily, so a
        # null table at call time self-heals instead of throwing.
        It 'rebuilds the role table when $script:MtRoles is $null at call time' {
            InModuleScope Maester {
                $script:MtRoles = $null
                $script:MtRoleAliases = $null

                $role = Get-MtRoleInfo -RoleName 'DirectorySynchronizationAccounts'

                "$role" | Should -Be 'd29b2b05-8046-44ba-8758-1e26182fcf32'
                $script:MtRoles | Should -Not -BeNullOrEmpty
                $script:MtRoleAliases | Should -Not -BeNull
            }
        }

        It 'resolves aliases when the tables are $null at call time' {
            InModuleScope Maester {
                $script:MtRoles = $null
                $script:MtRoleAliases = $null

                $role = Get-MtRoleInfo -RoleName 'AzureADJoinedDeviceLocalAdministrator'

                "$role" | Should -Be '9f06204d-73c1-4d4c-880a-6edb90606fd8'
            }
        }

        It 'still returns $null for an unknown role after a null table' {
            InModuleScope Maester {
                $script:MtRoles = $null
                $script:MtRoleAliases = $null

                Get-MtRoleInfo -RoleName 'ThisRoleDoesNotExist' | Should -BeNullOrEmpty
            }
        }
    }
}
