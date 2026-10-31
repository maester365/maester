function Get-MtDirectoryRoleMember {
    <#
    .SYNOPSIS
    Returns the principals that hold directory roles, with the members of role-assigned groups expanded.

    .DESCRIPTION
    Reads the role assignments with Get-MtDirectoryRoleAssignment and returns each assigned principal. When a role
    is assigned to a group, the group's members are returned instead of the group. Role-assignable groups cannot be
    nested, so one level is read.

    Unlike Get-MtRoleMember, this throws when a group's members cannot be read, so a check cannot pass without
    evaluating them. A group that no longer exists (404) is skipped.

    .EXAMPLE
    Get-MtDirectoryRoleMember -RoleId '62e90394-69f5-4237-9190-012177145e10' -MemberStatus Active

    Returns the principals with an active Global Administrator assignment, including members of role-assigned groups.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The IDs of the role definitions to return members for.
        [Parameter(Mandatory = $true)]
        [guid[]]$RoleId,

        # The type of assignments to read. Default is both Eligible and Active.
        [ValidateSet('Eligible', 'Active', 'EligibleAndActive')]
        [string]$MemberStatus = 'EligibleAndActive'
    )

    $roleAssignments = @((Get-MtDirectoryRoleAssignment -RoleId $RoleId -MemberStatus $MemberStatus -ExpandPrincipal -DisableCache).Assignments)
    foreach ($roleAssignment in $roleAssignments) {
        $principal = $roleAssignment.principal
        if ($null -eq $principal) { continue }
        if ($principal.'@odata.type' -ne '#microsoft.graph.group') {
            $principal
            continue
        }

        try {
            $groupMembers = @(Invoke-MtGraphRequest -RelativeUri "groups/$($principal.id)/members" -ApiVersion v1.0)
        } catch {
            if ($_.Exception.Response.StatusCode -eq 'NotFound') {
                Write-Verbose "Role-assigned group $($principal.id) was not found and is skipped."
                continue
            }
            throw "Could not read the members of role-assigned group $($principal.id): $($_.Exception.Message)"
        }
        foreach ($groupMember in $groupMembers) {
            if ($null -ne $groupMember) { $groupMember }
        }
    }
}
