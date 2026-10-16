function Get-MtRoleMember {
    <#
    .Synopsis
    Returns all the members of a role.

    .Description
    The role can be either active or eligible, defaults to getting members that are both active and eligible.

    If the assigned member is a group, all members of that group will be returned.

    .Example
    Get-MtRoleMember -Role GlobalAdministrator

    Returns all the Global Administrators and includes both Eligible and Active members.

    .Example
    Get-MtRoleMember -Role GlobalAdministrator -MemberStatus Active

    Returns all the Global Administrators that are currently active and excludes those that are eligible but not yet active.

    .EXAMPLE
    Get-MtRoleMember -Role GlobalAdministrator,PrivilegedRoleAdministrator

    Returns all the Global Administrators and Privileged Role administrators and includes both Eligible and Active members.

    .Example
    Get-MtRoleMember -RoleId "00000000-0000-0000-0000-000000000000"

    Returns all the members of the role with the specified RoleId and includes both Eligible and Active members.

    .Example
    Get-MtRoleMember -RoleId "00000000-0000-0000-0000-000000000000" -MemberStatus Active

    Returns all the currently active members of the role with the specified RoleId.

    .LINK
    https://maester.dev/docs/commands/Get-MtRoleMember
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'ArgumentCompleter requires the full script block signature, even when only wordToComplete is used.')]
    [CmdletBinding(DefaultParameterSetName = 'RoleName')]
    param(
        # The name of the role to get members for.
        [Parameter(ParameterSetName = 'RoleName', Position = 0, Mandatory = $true)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete)
                Initialize-MtRoleDefinition
                $roleNames = @($script:MtRoles.Keys) + @($script:MtRoleAliases.Keys)
                $roleNames |
                Where-Object { $_.StartsWith($wordToComplete, [System.StringComparison]::OrdinalIgnoreCase) } |
                Sort-Object | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateScript({
                Initialize-MtRoleDefinition
                $roleNames = @($script:MtRoles.Keys) + @($script:MtRoleAliases.Keys)
                if ($_ -in $roleNames) { return $true }
                throw "Unknown role '$_'. Use tab-completion to see valid role names."
            })]
        [string[]]$Role,

        # The ID of the role to get members for.
        [Parameter(ParameterSetName = 'RoleId', Position = 0, Mandatory = $true)]
        [guid[]]$RoleId,

        # The type of members to look for. Default is both Eligible and Active.
        [ValidateSet('Eligible', 'Active', 'EligibleAndActive')]
        [string]$MemberStatus
    )

    # Ensure the role lookup tables are built. Guards against the module-load-time
    # assignment of $script:MtRoles not persisting into the Pester test-execution
    # context (the cause of the MT.1020 NullReferenceException). See Get-MtRoleInfo.
    Initialize-MtRoleDefinition

    Write-Verbose "Getting members for RoleId: $RoleId, Role: $Role, MemberStatus: $MemberStatus"
    if (-not $MemberStatus) { $MemberStatus = 'EligibleAndActive' }

    if ($Role) {
        # Resolve role names to GUIDs via MtRoleDefinition.ToString(), then explicitly cast to [guid[]]
        # to avoid relying on implicit coercion from MtRoleDefinition through the typed parameter variable.
        $RoleId = [guid[]]($Role | ForEach-Object { (Get-MtRoleInfo -RoleName $_).ToString() })
    }

    $roleAssignments = (Get-MtDirectoryRoleAssignment -RoleId $RoleId -MemberStatus $MemberStatus -ExpandPrincipal).Assignments

    foreach ($directoryRoleId in $RoleId) {
        $assignments = @()
        foreach ($roleAssignment in $roleAssignments | Where-Object { $_.roleDefinitionId -eq "$directoryRoleId" }) {
            $principal = $roleAssignment.principal
            if ($null -eq $principal) { continue }

            $members = @($principal)
            if ($principal.'@odata.type' -eq '#microsoft.graph.group') {
                #5/10/2024 - Entra ID Role Enabled Security Groups do not currently support nesting
                # Get-MtGroupMember returns $null when a group cannot be resolved (e.g., GDAP external groups, deleted groups). Skip null results.
                $groupMembers = Get-MtGroupMember -GroupId $principal.id
                if ($null -ne $groupMembers) {
                    $members += $groupMembers
                }
            }

            # Append the type of assignment
            foreach ($member in $members) {
                $member | Add-Member -MemberType NoteProperty -Name 'AssignmentType' -Value $roleAssignment.AssignmentType -Force
            }
            $assignments += $members
        }

        $assignments | Sort-Object id -Unique
    }
}
