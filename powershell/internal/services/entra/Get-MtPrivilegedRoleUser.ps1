function Get-MtPrivilegedRoleUser {
    <#
    .SYNOPSIS
    Returns the users that hold a privileged directory role, with the names of their roles.

    .DESCRIPTION
    A role is privileged when Microsoft Entra marks its definition isPrivileged. Active and eligible assignments
    count. A user holds a role when it is assigned to them, or to a role-assignable group they are a member of.
    Principals that are not users are left out.

    Returns a hashtable from user object ID to the sorted, unique display names of the user's privileged
    roles. The hashtable is empty when nobody holds a privileged role.

    .EXAMPLE
    $privilegedUsers = Get-MtPrivilegedRoleUser -ExcludeEmergencyAccessAccount
    $privilegedUsers.Keys

    Returns the object IDs of the users that hold a privileged directory role, apart from the emergency access accounts.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        # Leave out the emergency access accounts named in the Maester configuration (EmergencyAccessAccounts).
        [switch] $ExcludeEmergencyAccessAccount
    )

    # isPrivileged can be filtered on in beta only; CIS.M365.5.3.1 reads the same list.
    $roleName = @{}
    foreach ($role in @(Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleDefinitions' -ApiVersion beta -Filter 'isPrivileged eq true')) {
        $roleName[$role.id] = $role.displayName
    }
    $excluded = if ($ExcludeEmergencyAccessAccount) { @(Get-MtEmergencyAccessAccount | ForEach-Object ObjectId) } else { @() }

    $rolesOf = @{}
    foreach ($assignment in @((Get-MtDirectoryRoleAssignment -ExpandPrincipal).Assignments | Where-Object { $roleName.ContainsKey($_.roleDefinitionId) })) {
        $principal = $assignment.principal
        $users = switch ([string]$principal.'@odata.type') {
            '#microsoft.graph.user' { @($principal) }
            # Role-assignable groups cannot be nested, so their members are the users who hold the role.
            '#microsoft.graph.group' { @(Get-MtGroupMember -GroupId $principal.id | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' }) }
            default { @() }
        }
        foreach ($user in $users) {
            if (-not $user.id -or $user.id -in $excluded) { continue }
            if (-not $rolesOf.ContainsKey($user.id)) { $rolesOf[$user.id] = [System.Collections.Generic.List[string]]::new() }
            $name = $roleName[$assignment.roleDefinitionId]
            if ($name -notin $rolesOf[$user.id]) { $rolesOf[$user.id].Add($name) }
        }
    }
    foreach ($id in @($rolesOf.Keys)) { $rolesOf[$id] = @($rolesOf[$id] | Sort-Object) }
    $rolesOf
}
