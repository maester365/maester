function Get-MtRoleUserSyncStatus {
    <#
    .SYNOPSIS
    Returns the users that hold any of the given directory roles, with whether each is synced from on-premises.

    .DESCRIPTION
    Reads the members of the roles with Get-MtRoleMember (active and eligible, including the members of
    role-assignable groups), keeps the users, and reads id, displayName and onPremisesSyncEnabled for each.

    Which roles to pass is the caller's decision: each benchmark defines its own set of privileged roles,
    and this helper only does the Graph reads they share.

    Throws when Graph does not return a user, or returns one without onPremisesSyncEnabled, so a check
    cannot pass without evaluating every member. Returns nothing when the roles have no user members.

    .EXAMPLE
    Get-MtRoleUserSyncStatus -RoleId '62e90394-69f5-4237-9190-012177145e10' | Where-Object onPremisesSyncEnabled

    Returns the Global Administrators that are synced from on-premises.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject], [object[]])]
    param(
        # The IDs of the role definitions whose user members to return.
        [Parameter(Mandatory)]
        [guid[]] $RoleId
    )

    $members = @(Get-MtRoleMember -RoleId $RoleId)
    $userIds = @($members | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' } |
            ForEach-Object { [string]$_.id } | Sort-Object -Unique)
    if ($userIds.Count -eq 0) { return }

    Write-Verbose "Reading onPremisesSyncEnabled for $($userIds.Count) role members"
    $users = @(Invoke-MtGraphRequest -RelativeUri 'users' -UniqueId $userIds -Select id, displayName, onPremisesSyncEnabled)

    $returnedUserIds = @($users | ForEach-Object { [string]$_.id })
    $missingUserIds = @($userIds | Where-Object { $_ -notin $returnedUserIds })
    if ($missingUserIds.Count -gt 0) {
        throw "Microsoft Graph did not return user details for all role members. Missing user IDs: $($missingUserIds -join ', ')."
    }

    $missingSyncStatusIds = @($users | Where-Object { $_.PSObject.Properties.Name -notcontains 'onPremisesSyncEnabled' } |
            ForEach-Object { [string]$_.id })
    if ($missingSyncStatusIds.Count -gt 0) {
        throw "Microsoft Graph did not return onPremisesSyncEnabled for role members: $($missingSyncStatusIds -join ', ')."
    }

    $users
}
