function Test-MtEntraAgentDirectoryRoles {
    <#
    .SYNOPSIS
    Finds Agent Identities and Blueprint Principals assigned privileged Entra directory roles.
    .DESCRIPTION
    Checks whether any Agent Identity or Agent Identity Blueprint Principal has been assigned
    privileged Entra directory roles (e.g., Global Administrator, Privileged Role Administrator,
    Agent ID Administrator, Application Administrator). Workload identities and AI agents should
    use least-privilege scoped permissions rather than broad administrative directory roles.
    .EXAMPLE
    Test-MtEntraAgentDirectoryRoles
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentDirectoryRoles
    .LINK
    https://learn.microsoft.com/graph/api/rbacapplication-list-roleassignments?view=graph-rest-1.0
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple directory roles.')]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Reading Agent Identities and Blueprint Principals.'
        $AgentIdentities = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentity' `
                -Select @('id', 'displayName', 'appId')
        )
        $BlueprintPrincipals = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal' `
                -Select @('id', 'displayName', 'appId')
        )

        $AgentLookup = @{}
        foreach ($AI in $AgentIdentities) {
            $AgentLookup[[string]$AI.id] = @{ Object = $AI; Type = 'Agent Identity' }
        }
        foreach ($BP in $BlueprintPrincipals) {
            $AgentLookup[[string]$BP.id] = @{ Object = $BP; Type = 'Blueprint Principal' }
        }

        Write-Verbose (
            "Auditing directory roles across $($AgentIdentities.Count) Agent Identities and " +
            "$($BlueprintPrincipals.Count) Blueprint Principals."
        )

        if ($AgentLookup.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No Agent Identities or Blueprint Principals were found in the tenant.'
            )
            return $true
        }

        Write-Verbose 'Reading directory role definitions and assignments.'
        $RoleDefinitions = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'roleManagement/directory/roleDefinitions' `
                -Select @('id', 'displayName', 'templateId')
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

        $RoleFindings = [System.Collections.Generic.List[pscustomobject]]::new()

        foreach ($Assignment in $RoleAssignments) {
            $PrincipalId = [string]$Assignment.principalId
            if (![string]::IsNullOrWhiteSpace($PrincipalId) -and $AgentLookup.ContainsKey($PrincipalId)) {
                $AgentInfo = $AgentLookup[$PrincipalId]
                $DefId = [string]$Assignment.roleDefinitionId
                $RoleDef = if ($RoleDefLookup.ContainsKey($DefId)) { $RoleDefLookup[$DefId] } else { $null }
                if ($null -eq $RoleDef) { continue }

                # isPrivileged is not a Graph-queryable property on unifiedRoleDefinition --
                # confirmed live, Graph returns 400 Bad Request for it in $select. Resolve
                # privilege from Maester's own built-in-roles catalog instead. A role Get-MtRoleInfo
                # cannot resolve (unrecognized name, or a custom role) is an observation, not a
                # confirmed privileged role.
                $RoleInfo = Get-MtRoleInfo -RoleName ([string]$RoleDef.displayName -replace '\s', '')
                if ($null -eq $RoleInfo -or !$RoleInfo.IsPrivileged) { continue }

                $RoleName = [string]$RoleDef.displayName

                $RoleFindings.Add([pscustomobject]@{
                    ObjectId      = $PrincipalId
                    DisplayName   = [string]$AgentInfo.Object.displayName
                    ObjectType    = [string]$AgentInfo.Type
                    RoleName      = $RoleName
                    Scope         = [string]$Assignment.directoryScopeId
                })
            }
        }

        if ($RoleFindings.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No Agent Identities or Blueprint Principals have been assigned privileged Entra directory roles.'
            )
            return $true
        }

        $Result = "Found $($RoleFindings.Count) Agent ID object(s) with privileged Entra directory role assignments."
        $Result += "`n`n| Object ID | Display name | Object type | Directory role | Directory scope |"
        $Result += "`n| --- | --- | --- | --- | --- |"
        foreach ($Item in $RoleFindings) {
            $Name = [string]$Item.DisplayName
            if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
            $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
            $Name = $Name -replace "`r?`n", ' '
            $RoleName = [System.Net.WebUtility]::HtmlEncode([string]$Item.RoleName) -replace '\|', '&#124;'
            $Scope = if ([string]::IsNullOrWhiteSpace($Item.Scope) -or $Item.Scope -eq '/') { 'Tenant-wide (/)' } else { $Item.Scope }
            $Result += "`n| ``$($Item.ObjectId)`` | $Name | $($Item.ObjectType) | $RoleName | $Scope |"
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
