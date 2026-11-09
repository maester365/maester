function Get-MtPrincipalPrivilegedRole {
    <#
    .SYNOPSIS
    Returns the privileged directory roles held by the given principals.

    .DESCRIPTION
    Shared by the Entra ID Protection risk checks (MT.1260 to MT.1263) so the privileged-role lookup lives in one place.

    For each principal ID passed in, returns the display names of the privileged directory roles assigned to it,
    active or PIM-eligible. Eligible roles get ' (eligible)' after the name. A role counts as privileged when
    Maester's role catalog (Get-MtRoleInfo) marks it IsPrivileged, as MT.1210 does.

    Only direct assignments are matched. A role held through a role-assignable group is not returned yet.

    The result has two properties: RolesByPrincipal, a hashtable from principal ID to a list of role names (only
    principals that hold a privileged role are present), and EligibleChecked, which is true when PIM-eligible
    assignments were read (they need Microsoft Entra ID P2 or Governance).

    Errors reading role definitions or assignments are not caught, so the caller can report that privileged
    principals could not be identified.

    .EXAMPLE
    $privileged = Get-MtPrincipalPrivilegedRole -PrincipalId $riskyUsers.id
    $privileged.RolesByPrincipal[$user.id]

    Returns the privileged roles held by each risky user.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Object IDs of the users or service principals to look up.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $PrincipalId
    )

    $wanted = @{}
    foreach ($id in $PrincipalId) {
        if (-not [string]::IsNullOrWhiteSpace($id)) { $wanted[[string]$id] = $true }
    }

    $roleDefinitions = @(
        Invoke-MtGraphRequest -ApiVersion 'v1.0' `
            -RelativeUri 'roleManagement/directory/roleDefinitions' `
            -Select @('id', 'displayName')
    )
    $roleDefinitionById = @{}
    foreach ($definition in $roleDefinitions) { $roleDefinitionById[[string]$definition.id] = $definition }

    # Same properties as MT.1209 and MT.1210 so the active assignments come from the Graph cache.
    $assignmentResult = Get-MtDirectoryRoleAssignment -Select @('id', 'principalId', 'roleDefinitionId', 'directoryScopeId')

    $rolesByPrincipal = @{}
    foreach ($assignment in @($assignmentResult.Assignments)) {
        $principal = [string]$assignment.principalId
        if (-not $wanted.ContainsKey($principal)) { continue }
        $definition = $roleDefinitionById[[string]$assignment.roleDefinitionId]
        if ($null -eq $definition) { continue }
        # isPrivileged is not queryable on roleDefinitions; use Maester's role catalog, as MT.1210 does.
        $roleInfo = Get-MtRoleInfo -RoleName ([string]$definition.displayName -replace '\s', '')
        if ($null -eq $roleInfo -or -not $roleInfo.IsPrivileged) { continue }
        $roleName = [string]$definition.displayName
        if ($assignment.AssignmentType -eq 'Eligible') { $roleName += ' (eligible)' }
        if (-not $rolesByPrincipal.ContainsKey($principal)) {
            $rolesByPrincipal[$principal] = [System.Collections.Generic.List[string]]::new()
        }
        $rolesByPrincipal[$principal].Add($roleName)
    }

    [pscustomobject]@{
        RolesByPrincipal = $rolesByPrincipal
        EligibleChecked  = [bool]$assignmentResult.EligibleChecked
    }
}
