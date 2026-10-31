BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Get-MtDirectoryRoleMember
}

Describe 'Get-MtDirectoryRoleMember' -Tag 'Unit' {
    BeforeAll {
        function New-HttpResponseException ([System.Net.HttpStatusCode]$StatusCode) {
            $response = [System.Net.Http.HttpResponseMessage]::new($StatusCode)
            [Microsoft.PowerShell.Commands.HttpResponseException]::new("$StatusCode", $response)
        }
    }

    BeforeEach {
        Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
            [pscustomobject]@{
                Assignments     = @(
                    [pscustomobject]@{ roleDefinitionId = 'role-1'; principal = [pscustomobject]@{ id = 'user-1'; '@odata.type' = '#microsoft.graph.user' } }
                    [pscustomobject]@{ roleDefinitionId = 'role-1'; principal = [pscustomobject]@{ id = 'group-1'; '@odata.type' = '#microsoft.graph.group' } }
                    [pscustomobject]@{ roleDefinitionId = 'role-1'; principal = $null }
                )
                EligibleChecked = $false
            }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ id = 'user-2'; '@odata.type' = '#microsoft.graph.user' }
        } -ParameterFilter { $RelativeUri -eq 'groups/group-1/members' }
    }

    It 'returns assigned principals and the members of role-assigned groups' {
        $result = @(Get-MtDirectoryRoleMember -RoleId '62e90394-69f5-4237-9190-012177145e10' -MemberStatus Active)

        $result.id | Should -Be @('user-1', 'user-2')
        Should -Invoke Get-MtDirectoryRoleAssignment -ModuleName Maester -Exactly 1 -ParameterFilter {
            $MemberStatus -eq 'Active' -and $ExpandPrincipal -and $DisableCache
        }
    }

    It 'throws when the members of a role-assigned group cannot be read' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            throw (New-HttpResponseException -StatusCode Forbidden)
        } -ParameterFilter { $RelativeUri -eq 'groups/group-1/members' }

        { Get-MtDirectoryRoleMember -RoleId '62e90394-69f5-4237-9190-012177145e10' } |
            Should -Throw '*Could not read the members of role-assigned group group-1*'
    }

    It 'skips a role-assigned group that no longer exists' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            throw (New-HttpResponseException -StatusCode NotFound)
        } -ParameterFilter { $RelativeUri -eq 'groups/group-1/members' }

        $result = @(Get-MtDirectoryRoleMember -RoleId '62e90394-69f5-4237-9190-012177145e10')

        $result.id | Should -Be 'user-1'
    }
}
