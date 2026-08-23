function Test-MtEntraAgentUserExcessiveAccess {
    <#
    .SYNOPSIS
    Finds Agent Users with privileged directory roles or membership in role-assignable groups.
    .DESCRIPTION
    Checks whether any Agent User has been assigned Entra directory roles or added to
    role-assignable security groups. Agent Users represent specialized non-human user accounts
    paired with Agent Identities and should never hold directory-level administrative privileges.
    .EXAMPLE
    Test-MtEntraAgentUserExcessiveAccess
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentUserExcessiveAccess
    .LINK
    https://learn.microsoft.com/graph/api/agentuser-list?view=graph-rest-1.0
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Reading Agent Users.'
        $AgentUsers = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'users/microsoft.graph.agentUser' `
                -Select @('id', 'displayName', 'userPrincipalName', 'identityParentId')
        )

        Write-Verbose "Found $($AgentUsers.Count) Agent Users."

        if ($AgentUsers.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No Agent Users found in the tenant.'
            )
            return $true
        }

        Write-Verbose 'Reading directory role definitions and assignments.'
        $RoleDefinitions = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'roleManagement/directory/roleDefinitions' `
                -Select @('id', 'displayName')
        )
        $RoleAssignments = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'roleManagement/directory/roleAssignments' `
                -Select @('id', 'principalId', 'roleDefinitionId', 'directoryScopeId')
        )

        $RoleDefLookup = @{}
        foreach ($Def in $RoleDefinitions) {
            $RoleDefLookup[[string]$Def.id] = $Def
        }

        $AssignmentsByUser = @{}
        foreach ($Assignment in $RoleAssignments) {
            $AssignedPrincipalId = [string]$Assignment.principalId
            if (![string]::IsNullOrWhiteSpace($AssignedPrincipalId)) {
                if (!$AssignmentsByUser.ContainsKey($AssignedPrincipalId)) {
                    $AssignmentsByUser[$AssignedPrincipalId] = [System.Collections.Generic.List[object]]::new()
                }
                $AssignmentsByUser[$AssignedPrincipalId].Add($Assignment)
            }
        }

        $ExcessiveAccessFindings = [System.Collections.Generic.List[pscustomobject]]::new()

        foreach ($User in $AgentUsers) {
            $UserId = [string]$User.id
            if ([string]::IsNullOrWhiteSpace($UserId)) { continue }

            # 1. Direct privileged directory roles. A role Get-MtRoleInfo does not resolve, or
            # has not classified as privileged, is an observation, not a confirmed finding.
            # isPrivileged is not a Graph-queryable property on unifiedRoleDefinition --
            # confirmed live, Graph returns 400 Bad Request for it in $select. Resolve privilege
            # from Maester's own built-in-roles catalog instead.
            if ($AssignmentsByUser.ContainsKey($UserId)) {
                foreach ($Assigned in $AssignmentsByUser[$UserId]) {
                    $DefId = [string]$Assigned.roleDefinitionId
                    $RoleDef = if ($RoleDefLookup.ContainsKey($DefId)) { $RoleDefLookup[$DefId] } else { $null }
                    if ($null -eq $RoleDef) { continue }
                    $RoleInfo = Get-MtRoleInfo -RoleName ([string]$RoleDef.displayName -replace '\s', '')
                    if ($null -eq $RoleInfo -or !$RoleInfo.IsPrivileged) { continue }

                    $ExcessiveAccessFindings.Add([pscustomobject]@{
                        UserId            = $UserId
                        DisplayName       = [string]$User.displayName
                        UserPrincipalName = [string]$User.userPrincipalName
                        AccessType        = 'Directory Role'
                        PrivilegedItem    = [string]$RoleDef.displayName
                        Reason            = 'Directly assigned a privileged Entra directory role.'
                    })
                }
            }

            # 2. Role-assignable group memberships
            $GroupMemberships = @(
                Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                    -RelativeUri "users/$UserId/transitiveMemberOf/microsoft.graph.group" `
                    -Select @('id', 'displayName', 'isAssignableToRole', 'securityEnabled')
            )

            foreach ($Group in $GroupMemberships) {
                if ($Group.isAssignableToRole -eq $true) {
                    $ExcessiveAccessFindings.Add([pscustomobject]@{
                        UserId            = $UserId
                        DisplayName       = [string]$User.displayName
                        UserPrincipalName = [string]$User.userPrincipalName
                        AccessType        = 'Role-Assignable Group'
                        PrivilegedItem    = [string]$Group.displayName
                        Reason            = 'Member of a role-assignable security group.'
                    })
                }
            }
        }

        if ($ExcessiveAccessFindings.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No Agent Users have privileged directory roles or membership in role-assignable groups.'
            )
            return $true
        }

        $Result = "Found $($ExcessiveAccessFindings.Count) excessive privilege finding(s) across Agent Users."
        $Result += "`n`n| Agent User object ID | Display name | User principal name | Access type | Privileged item | Reason |"
        $Result += "`n| --- | --- | --- | --- | --- | --- |"
        foreach ($Item in $ExcessiveAccessFindings) {
            $Name = [string]$Item.DisplayName
            if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
            $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
            $Name = $Name -replace "`r?`n", ' '
            $UPN = [System.Net.WebUtility]::HtmlEncode([string]$Item.UserPrincipalName) -replace '\|', '&#124;'
            $PrivItem = [System.Net.WebUtility]::HtmlEncode([string]$Item.PrivilegedItem) -replace '\|', '&#124;'
            $Reason = [System.Net.WebUtility]::HtmlEncode([string]$Item.Reason) -replace '\|', '&#124;'
            $Result += "`n| $($Item.UserId) | $Name | $UPN | $($Item.AccessType) | " +
                "$PrivItem | $Reason |"
        }

        Add-MtTestResultDetail -Result $Result -Severity 'High'
        return $false
    } catch {
        $ErrorRecord = $_
    }

    if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
    } else {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
    }
    return $null
}
