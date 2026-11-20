function Test-MtEntraUnremediatedMediumRiskAgent {
    <#
    .SYNOPSIS
    Finds agents that Entra ID Protection rates medium risk and that nobody has remediated.
    .DESCRIPTION
    Entra ID Protection flags agents (agent identities, agent identity blueprint principals and agents'
    user accounts) it believes are compromised and assigns a risk level and a risk state. Microsoft documents
    admin actions (confirm safe, dismiss risk) as the way to clear an agent's risk. This check reports agents whose
    risk level is medium and whose risk state still shows active, unremediated risk, so an admin can act
    on flags that have been left sitting. If a reported agent holds a privileged directory role, it is
    listed first with its roles. It reads risk only; it never changes an agent's risk state.
    .EXAMPLE
    Test-MtEntraUnremediatedMediumRiskAgent
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraUnremediatedMediumRiskAgent
    .LINK
    https://learn.microsoft.com/graph/api/resources/riskyagent?view=graph-rest-beta
    #>
    [MaesterTest(
        Id = 'MT.1285',
        Title = 'Medium-risk agents should not be left unremediated in Entra ID Protection.',
        Product = 'entra',
        Feature = 'identity-protection',
        Area = 'ai',
        ResourceType = 'Agent',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Control = ('nist-800-53-r5:AC-2(12)', 'nist-800-53-r5:IR-4'),
        Cloud = ('Commercial', 'GCC', 'GCCHigh', 'DoD'),
        Service = 'Graph',
        License = 'AAD_PREMIUM_P2&AGENT_365',
        Permission = ('Graph:Scope:IdentityRiskyAgent.Read.All', 'Graph:Scope:RoleManagement.Read.Directory|Graph:Scope:RoleManagement.Read.All'),
        Lifecycle = 'Preview',
        Author = 'Dfrank77'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Active, unremediated risk states, same as MT.1262. 'confirmedCompromised' is still unremediated:
    # an admin confirming an agent compromised raises its risk to high and does not clear it.
    $UnremediatedStates = @('atRisk', 'confirmedCompromised')

    # Each item's @odata.type says which kind of agent it is (riskyAgentIdentity, riskyAgentUser or
    # riskyAgentIdentityBlueprintPrincipal). It is read first because identityType is an evolvable enum:
    # without the Prefer: include-unknown-enum-members header, which Invoke-MtGraphRequest can't send, Graph
    # returns blueprint principals as unknownFutureValue. identityType is the fallback.
    # Name shown in the table, and the object type used on the report's Affected objects page. Agents' user
    # accounts and regular user accounts are users; agent identities and blueprint principals are service principals.
    $AgentTypes = @{
        '#microsoft.graph.riskyAgentIdentity'                   = @{ Name = 'Agent identity'; ObjectType = '#microsoft.graph.servicePrincipal' }
        '#microsoft.graph.riskyAgentUser'                       = @{ Name = 'Agent user'; ObjectType = '#microsoft.graph.user' }
        '#microsoft.graph.riskyAgentIdentityBlueprintPrincipal' = @{ Name = 'Blueprint principal'; ObjectType = '#microsoft.graph.servicePrincipal' }
        'agentIdentity'                                         = @{ Name = 'Agent identity'; ObjectType = '#microsoft.graph.servicePrincipal' }
        'agentUser'                                             = @{ Name = 'Agent user'; ObjectType = '#microsoft.graph.user' }
        'agentIdentityBlueprintPrincipal'                       = @{ Name = 'Blueprint principal'; ObjectType = '#microsoft.graph.servicePrincipal' }
        'user'                                                  = @{ Name = 'User'; ObjectType = '#microsoft.graph.user' }
    }
    $GetAgentType = {
        param($Item)
        foreach ($Key in @([string]$Item.'@odata.type', [string]$Item.identityType)) {
            if ($Key -and $AgentTypes.ContainsKey($Key)) { return $AgentTypes[$Key] }
        }
        # An agent of a kind Maester doesn't know yet is still reported, but not linked as an object of a guessed type.
        return @{ Name = 'Other agent'; ObjectType = $null }
    }

    # Microsoft documents the agent values of riskDetail as evolvable too (unknownFutureValue without the
    # Prefer header; in testing Graph returned them anyway), so that value points the admin to the portal
    # instead of showing the sentinel.
    $RiskDetailUnknown = 'Not returned by Graph, see the Risky agents report'

    Write-Verbose 'Reading medium-risk agents from Entra ID Protection.'
    # Agent risk is a separate list from riskyServicePrincipals and is available in Microsoft Graph beta only.
    # Filter riskLevel server-side and apply the riskState set client-side, same as MT.1262.
    try {
        $MediumRiskAgents = @(
            Invoke-MtGraphRequest -ApiVersion 'beta' `
                -RelativeUri 'identityProtection/riskyAgents' `
                -Filter "riskLevel eq 'medium'"
        )
    } catch {
        if ($_.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }
        throw
    }

    # Deleted agents stay in the risk list, but a deleted agent cannot sign in and leaves nothing to act on.
    # Disabled agents are still reported: disabling only blocks sign-ins, and the risk stays open until an
    # admin dismisses it or confirms the agent safe.
    $Unremediated = @(
        $MediumRiskAgents | Where-Object {
            ($UnremediatedStates -contains [string]$_.riskState) -and ($_.isDeleted -ne $true)
        }
    )
    Write-Verbose "Found $($MediumRiskAgents.Count) medium-risk agent(s); $($Unremediated.Count) unremediated and not deleted."

    if ($Unremediated.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            'Well done. No medium-risk agents are left unremediated in Entra ID Protection.'
        )
        return $true
    }

    # Agents at risk that hold a privileged role are listed first with their roles, as MT.1262 does for
    # service principals. Roles are only read when there is something to report. If the lookup fails, the
    # unremediated agents are still reported, with a note.
    $PrivilegedRolesByAgent = @{}
    $RoleNote = ''
    try {
        $RoleDefinitions = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'roleManagement/directory/roleDefinitions' `
                -Select @('id', 'displayName')
        )
        $RoleDefLookup = @{}
        foreach ($Def in $RoleDefinitions) { $RoleDefLookup[[string]$Def.id] = $Def }

        # Same properties as MT.1209, MT.1210 and MT.1262 so the active assignments come from the Graph cache.
        $RoleAssignmentResult = Get-MtDirectoryRoleAssignment -Select @('id', 'principalId', 'roleDefinitionId', 'directoryScopeId')
        if (!$RoleAssignmentResult.EligibleChecked) {
            $RoleNote = "`n`nNote: PIM-eligible role assignments were not checked because they need " +
                'Microsoft Entra ID P2 or Governance. Only active role assignments were checked.'
        }

        $UnremediatedIds = @{}
        foreach ($Item in $Unremediated) { $UnremediatedIds[[string]$Item.id] = $true }

        foreach ($Assignment in @($RoleAssignmentResult.Assignments)) {
            $PrincipalId = [string]$Assignment.principalId
            if (!$UnremediatedIds.ContainsKey($PrincipalId)) { continue }
            $RoleDef = $RoleDefLookup[[string]$Assignment.roleDefinitionId]
            if ($null -eq $RoleDef) { continue }
            $RoleInfo = Get-MtRoleInfo -RoleName ([string]$RoleDef.displayName -replace '\s', '')
            if ($null -eq $RoleInfo -or !$RoleInfo.IsPrivileged) { continue }
            $RoleName = [string]$RoleDef.displayName
            if ($Assignment.AssignmentType -eq 'Eligible') { $RoleName += ' (eligible)' }
            if (!$PrivilegedRolesByAgent.ContainsKey($PrincipalId)) {
                $PrivilegedRolesByAgent[$PrincipalId] = [System.Collections.Generic.List[string]]::new()
            }
            $PrivilegedRolesByAgent[$PrincipalId].Add($RoleName)
        }
    } catch {
        Write-Verbose "Could not read directory role assignments: $($_.Exception.Message)"
        $PrivilegedRolesByAgent = @{}
        $RoleNote = "`n`nNote: Directory role assignments could not be read, so privileged agents were not identified."
    }

    # Privileged agents first, then by display name.
    $Sorted = @(
        $Unremediated | Sort-Object -Property @{ Expression = { -not $PrivilegedRolesByAgent.ContainsKey([string]$_.id) } }, agentDisplayName
    )
    $PrivilegedCount = @($Unremediated | Where-Object { $PrivilegedRolesByAgent.ContainsKey([string]$_.id) }).Count

    $Result = "Found $($Unremediated.Count) medium-risk agent(s) with unremediated risk."
    if ($PrivilegedCount -gt 0) {
        $Result += " $PrivilegedCount of them hold a privileged directory role and are listed first."
    }
    $Result += "`n`n| Agent | Type | Object ID | Enabled | Risk state | Risk detail | Risk last updated | Privileged role |"
    $Result += "`n| --- | --- | --- | --- | --- | --- | --- | --- |"
    foreach ($Item in $Sorted) {
        # The agent's name comes from the tenant, so it is escaped. The (unnamed) placeholder is ours and is not.
        $DisplayName = if ([string]::IsNullOrWhiteSpace([string]$Item.agentDisplayName)) { '(unnamed)' } else { Get-MtSafeMarkdown ([string]$Item.agentDisplayName) }
        $Type = (& $GetAgentType $Item).Name
        $Enabled = if ($Item.isEnabled -eq $false) { 'No' } elseif ($Item.isEnabled -eq $true) { 'Yes' } else { 'Unknown' }
        $State = [string]$Item.riskState
        $Detail = if ([string]$Item.riskDetail -eq 'unknownFutureValue') { $RiskDetailUnknown } else { Get-MtSafeMarkdown ([string]$Item.riskDetail) }
        $UpdatedDate = $Item.riskLastModifiedDateTime -as [datetime]
        $Updated = if ($UpdatedDate) { $UpdatedDate.ToUniversalTime().ToString('yyyy-MM-dd') } else { 'Unknown' }
        $Roles = if ($PrivilegedRolesByAgent.ContainsKey([string]$Item.id)) {
            Get-MtSafeMarkdown ($PrivilegedRolesByAgent[[string]$Item.id] -join ', ')
        } else { 'None' }
        $Result += "`n| $DisplayName | $Type | $($Item.id) | $Enabled | $State | $Detail | $Updated | $Roles |"
    }
    $Result += $RoleNote

    # Each risky agent of a known kind also appears on the report's Affected objects page; the table above stays as it is.
    $AffectedAgents = @(
        $Sorted | ForEach-Object {
            $ObjectType = (& $GetAgentType $_).ObjectType
            if ($ObjectType) {
                [pscustomobject]@{ id = [string]$_.id; displayName = [string]$_.agentDisplayName; '@odata.type' = $ObjectType }
            }
        }
    )
    Add-MtTestResultDetail -Result $Result -GraphObjects $AffectedAgents
    return $false
}
