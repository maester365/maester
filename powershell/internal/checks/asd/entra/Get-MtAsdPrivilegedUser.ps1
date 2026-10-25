function Get-MtAsdPrivilegedUser {
    <#
    .SYNOPSIS
    Returns the users that hold a privileged directory role, with the names of their roles, for the ASD checks.

    .DESCRIPTION
    Shared by the Essential Eight Restrict administrative privileges checks. A role is privileged when Microsoft
    Entra marks its definition isPrivileged. Active and eligible assignments count. The emergency access
    accounts named in the Maester configuration (EmergencyAccessAccounts) are left out, and so is every
    principal that is not a user.

    Returns a hashtable from user object ID to the sorted, unique display names of the user's privileged
    roles. The hashtable is empty when nobody holds a privileged role.

    .EXAMPLE
    $privilegedUsers = Get-MtAsdPrivilegedUser
    $privilegedUsers.Keys

    Returns the object IDs of the users that hold a privileged directory role.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $roles = @(Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleDefinitions' -Select id, displayName, isPrivileged | Where-Object { $_.isPrivileged -eq $true })
    $roleName = @{}
    foreach ($role in $roles) { $roleName[$role.id] = $role.displayName }
    $breakGlass = @(Get-MtEmergencyAccessAccount | ForEach-Object ObjectId)

    $assignments = @((Get-MtDirectoryRoleAssignment -ExpandPrincipal).Assignments | Where-Object {
            $roleName.ContainsKey($_.roleDefinitionId) -and
            $_.principal.'@odata.type' -eq '#microsoft.graph.user' -and
            $_.principalId -notin $breakGlass
        })
    $rolesOf = @{}
    foreach ($assignment in $assignments) {
        if (-not $rolesOf.ContainsKey($assignment.principalId)) { $rolesOf[$assignment.principalId] = [System.Collections.Generic.List[string]]::new() }
        $name = $roleName[$assignment.roleDefinitionId]
        if ($name -notin $rolesOf[$assignment.principalId]) { $rolesOf[$assignment.principalId].Add($name) }
    }
    foreach ($id in @($rolesOf.Keys)) { $rolesOf[$id] = @($rolesOf[$id] | Sort-Object) }
    $rolesOf
}
