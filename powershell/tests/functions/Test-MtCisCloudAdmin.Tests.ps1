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

    It 'errors when Graph omits an administrative user from the details response' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{
                id                    = 'global-admin'
                displayName           = 'global-admin'
                onPremisesSyncEnabled = $false
            }
        }

        InModuleScope Maester {
            { Test-MtCisCloudAdmin } | Should -Throw '*did not return user details*'
        }
    }

    It 'errors when Graph omits onPremisesSyncEnabled for a requested user' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            foreach ($userId in $UniqueId) {
                [pscustomobject]@{
                    id          = $userId
                    displayName = $userId
                }
            }
        }

        InModuleScope Maester {
            { Test-MtCisCloudAdmin } | Should -Throw '*did not return onPremisesSyncEnabled*'
        }
    }
}

Describe 'Test-MtCisCloudAdmin role-assigned groups' -Tag 'Unit' {
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
            { Test-MtCisCloudAdmin } | Should -Throw '*Could not read the members of group (33333333-3333-3333-3333-333333333333)*403*'
        }

        Should -Not -Invoke Invoke-MtGraphRequest -ModuleName Maester -ParameterFilter { $RelativeUri -eq 'users' }
        Should -Not -Invoke Add-MtTestResultDetail -ModuleName Maester
    }
}
