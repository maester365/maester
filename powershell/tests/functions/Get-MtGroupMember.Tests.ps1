BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
}

Describe 'Get-MtGroupMember' -Tag 'Unit' {
    BeforeAll {
        $script:GroupId = '11111111-1111-1111-1111-111111111111'
        $script:NestedGroupId = '22222222-2222-2222-2222-222222222222'

        function Get-HttpError ([int]$StatusCode) {
            $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$StatusCode)
            [Microsoft.PowerShell.Commands.HttpResponseException]::new("Response status code does not indicate success: $StatusCode.", $response)
        }
    }

    BeforeEach {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ id = 'user-1'; '@odata.type' = '#microsoft.graph.user' }
        } -ParameterFilter { $RelativeUri -like 'groups/*/members' }
    }

    It 'returns the members of the group with one request' {
        $members = @(Get-MtGroupMember -GroupId $script:GroupId)

        $members.id | Should -Be 'user-1'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1
    }

    It 'returns nothing for a group that is not found' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw (Get-HttpError 404) } -ParameterFilter { $RelativeUri -like 'groups/*/members' }

        Get-MtGroupMember -GroupId $script:GroupId | Should -BeNullOrEmpty
    }

    It 'throws when the members cannot be read' -ForEach @(
        @{ StatusCode = 403 }
        @{ StatusCode = 429 }
    ) {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw (Get-HttpError $StatusCode) } -ParameterFilter { $RelativeUri -like 'groups/*/members' }

        { Get-MtGroupMember -GroupId $script:GroupId } | Should -Throw "Could not read the members of group ($script:GroupId)*$StatusCode*"
    }

    It 'keeps the Graph error as the inner exception' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw (Get-HttpError 403) } -ParameterFilter { $RelativeUri -like 'groups/*/members' }

        $thrown = $null
        try { Get-MtGroupMember -GroupId $script:GroupId } catch { $thrown = $_ }

        $thrown.FullyQualifiedErrorId | Should -BeLike 'MtGroupMemberReadFailed*'
        [int]$thrown.Exception.InnerException.Response.StatusCode | Should -Be 403
    }

    It 'stops the calling script when the members cannot be read' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw (Get-HttpError 403) } -ParameterFilter { $RelativeUri -like 'groups/*/members' }
        $script:ReachedNextStatement = $false

        {
            $null = Get-MtGroupMember -GroupId $script:GroupId
            $script:ReachedNextStatement = $true
        } | Should -Throw
        $script:ReachedNextStatement | Should -BeFalse
    }

    It 'throws when a nested group cannot be read' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ id = $script:NestedGroupId; '@odata.type' = '#microsoft.graph.group' }
        } -ParameterFilter { $RelativeUri -eq "groups/$script:GroupId/members" }
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw (Get-HttpError 403) } -ParameterFilter { $RelativeUri -eq "groups/$script:NestedGroupId/members" }

        { Get-MtGroupMember -GroupId $script:GroupId -Recursive } | Should -Throw "*$script:NestedGroupId*403*"
    }
}

Describe 'Get-MtRoleMember group expansion' -Tag 'Unit' {
    BeforeAll {
        function Get-HttpError ([int]$StatusCode) {
            $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$StatusCode)
            [Microsoft.PowerShell.Commands.HttpResponseException]::new("Response status code does not indicate success: $StatusCode.", $response)
        }
    }

    BeforeEach {
        Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
            [pscustomobject]@{
                Assignments = @([pscustomobject]@{
                        roleDefinitionId = '62e90394-69f5-4237-9190-012177145e10'
                        AssignmentType   = 'Active'
                        principal        = [pscustomobject]@{ id = '33333333-3333-3333-3333-333333333333'; '@odata.type' = '#microsoft.graph.group' }
                    })
            }
        }
    }

    It 'throws when a role-assigned group cannot be read' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw (Get-HttpError 403) }

        { Get-MtRoleMember -RoleId '62e90394-69f5-4237-9190-012177145e10' } | Should -Throw '*33333333-3333-3333-3333-333333333333*403*'
    }

    It 'skips a role-assigned group that is not found' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw (Get-HttpError 404) }

        $members = @(Get-MtRoleMember -RoleId '62e90394-69f5-4237-9190-012177145e10')

        $members.id | Should -Be '33333333-3333-3333-3333-333333333333'
    }

    It 'reads role assignments through the session cache' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { [pscustomobject]@{ id = '33333333-3333-3333-3333-333333333333' } }

        $null = Get-MtRoleMember -RoleId '62e90394-69f5-4237-9190-012177145e10'

        Should -Invoke Get-MtDirectoryRoleAssignment -ModuleName Maester -Exactly 1 -ParameterFilter { -not $DisableCache }
    }
}
