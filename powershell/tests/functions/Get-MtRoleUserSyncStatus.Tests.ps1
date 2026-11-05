BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Get-MtRoleUserSyncStatus
}

Describe 'Get-MtRoleUserSyncStatus' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName Maester Get-MtRoleMember {
            [pscustomobject]@{ id = 'cloud-admin'; '@odata.type' = '#microsoft.graph.user' }
            [pscustomobject]@{ id = 'synced-admin'; '@odata.type' = '#microsoft.graph.user' }
            # The same user in a second role, and a service principal, are each left out.
            [pscustomobject]@{ id = 'synced-admin'; '@odata.type' = '#microsoft.graph.user' }
            [pscustomobject]@{ id = 'app'; '@odata.type' = '#microsoft.graph.servicePrincipal' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            foreach ($userId in $UniqueId) {
                [pscustomobject]@{ id = $userId; displayName = $userId; onPremisesSyncEnabled = $userId -eq 'synced-admin' }
            }
        }
    }

    It 'returns the sync status of each user member once' {
        $users = @(Get-MtRoleUserSyncStatus -RoleId '62e90394-69f5-4237-9190-012177145e10')

        $users.id | Should -Be @('cloud-admin', 'synced-admin')
        ($users | Where-Object onPremisesSyncEnabled).id | Should -Be 'synced-admin'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter {
            $RelativeUri -eq 'users' -and ($UniqueId -join ',') -eq 'cloud-admin,synced-admin' -and
            ($Select -join ',') -eq 'id,displayName,onPremisesSyncEnabled'
        }
    }

    It 'reads no users when the roles have no user members' {
        Mock -ModuleName Maester Get-MtRoleMember { [pscustomobject]@{ id = 'app'; '@odata.type' = '#microsoft.graph.servicePrincipal' } }

        Get-MtRoleUserSyncStatus -RoleId '62e90394-69f5-4237-9190-012177145e10' | Should -BeNullOrEmpty
        Should -Not -Invoke Invoke-MtGraphRequest -ModuleName Maester
    }

    It 'errors when Graph does not return a user' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ id = 'cloud-admin'; displayName = 'cloud-admin'; onPremisesSyncEnabled = $false }
        }

        { Get-MtRoleUserSyncStatus -RoleId '62e90394-69f5-4237-9190-012177145e10' } | Should -Throw '*Missing user IDs: synced-admin*'
    }

    It 'errors when Graph leaves out onPremisesSyncEnabled' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            foreach ($userId in $UniqueId) { [pscustomobject]@{ id = $userId; displayName = $userId } }
        }

        { Get-MtRoleUserSyncStatus -RoleId '62e90394-69f5-4237-9190-012177145e10' } | Should -Throw '*did not return onPremisesSyncEnabled*'
    }
}
