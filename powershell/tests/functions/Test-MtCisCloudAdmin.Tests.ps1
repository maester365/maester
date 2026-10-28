BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
}

Describe 'Test-MtCisCloudAdmin' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName Maester Get-MtRole {
            @(
                [pscustomobject]@{ id = '62e90394-69f5-4237-9190-012177145e10'; displayName = 'Global Administrator' }
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000001'; displayName = 'Exchange Administrator' }
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000002'; displayName = 'Global Reader' }
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000003'; displayName = 'Directory Reader' }
            )
        }
        Mock -ModuleName Maester Get-MtRoleMember {
            $roleIds = @($RoleId | ForEach-Object { "$_" })
            if ('62e90394-69f5-4237-9190-012177145e10' -in $roleIds) {
                [pscustomobject]@{ id = 'global-admin'; '@odata.type' = '#microsoft.graph.user' }
            }
            if ('00000000-0000-0000-0000-000000000001' -in $roleIds) {
                [pscustomobject]@{ id = 'synced-admin'; '@odata.type' = '#microsoft.graph.user' }
            }
            if ('00000000-0000-0000-0000-000000000002' -in $roleIds) {
                [pscustomobject]@{ id = 'global-reader'; '@odata.type' = '#microsoft.graph.user' }
            }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            foreach ($userId in $UniqueId) {
                [pscustomobject]@{
                    id                      = $userId
                    displayName             = $userId
                    onPremisesSyncEnabled   = $userId -eq 'synced-admin'
                }
            }
        }
        Mock -ModuleName Maester Add-MtTestResultDetail { }
    }

    It 'checks synchronized users in every administrative role and Global Reader' {
        InModuleScope Maester {
            Test-MtCisCloudAdmin | Should -BeFalse
        }

        Should -Invoke Get-MtRoleMember -ModuleName Maester -Exactly 1 -ParameterFilter {
            $roleIds = @($RoleId | ForEach-Object { "$_" })
            $expectedRoleIds = @(
                '62e90394-69f5-4237-9190-012177145e10',
                '00000000-0000-0000-0000-000000000001',
                '00000000-0000-0000-0000-000000000002'
            )
            $roleIds.Count -eq $expectedRoleIds.Count -and
            @($expectedRoleIds | Where-Object { $_ -notin $roleIds }).Count -eq 0
        }
    }
}