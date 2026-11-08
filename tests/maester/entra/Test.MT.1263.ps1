function Test-MtEntraUnremediatedMediumRiskServicePrincipal {
    <#
    .SYNOPSIS
    Finds service principals that Entra ID Protection rates medium risk and that nobody has remediated.
    .DESCRIPTION
    Entra ID Protection flags service principals (workload identities) it believes are compromised
    and assigns a risk level and a risk state. A flag only clears when an admin remediates or
    dismisses it. This check reports service principals whose risk level is
    medium and whose risk state still shows active, unremediated risk, so an admin can act on flags
    that have been left sitting. If a reported service principal holds a privileged directory role,
    it is listed first with its roles. It reads risk only; it never changes a service principal's risk state.
    .EXAMPLE
    Test-MtEntraUnremediatedMediumRiskServicePrincipal
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraUnremediatedMediumRiskServicePrincipal
    .LINK
    https://learn.microsoft.com/graph/api/resources/riskyserviceprincipal?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id = 'MT.1263',
        Title = 'Medium-risk service principals should not be left unremediated in Entra ID Protection.',
        Product = 'entra',
        Feature = 'identity-protection',
        Area = 'applications',
        ResourceType = 'ServicePrincipal',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Control = ('nist-800-53-r5:AC-2(12)', 'nist-800-53-r5:IR-4'),
        Cloud = ('Commercial', 'GCC', 'GCCHigh', 'DoD'),
        Service = 'Graph',
        License = 'AAD_WRKLDID_P1',
        Permission = ('Graph:Scope:IdentityRiskyServicePrincipal.Read.All', 'Graph:Scope:RoleManagement.Read.Directory|Graph:Scope:RoleManagement.Read.All'),
        Lifecycle = 'Preview',
        Author = 'Dfrank77'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Active, unremediated risk states, same as MT.1261. 'confirmedCompromised' is still unremediated:
    # confirming a service principal compromised does not clear the risk, and the confirmCompromised
    # API (the documented way to simulate risk for testing) lands service principals in this state.
    $UnremediatedStates = @('atRisk', 'confirmedCompromised')

    Write-Verbose 'Reading medium-risk service principals from Entra ID Protection.'
    # Filter riskLevel server-side only and apply the riskState set client-side, same as MT.1261.
    try {
        $MediumRiskServicePrincipals = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'identityProtection/riskyServicePrincipals' `
                -Filter "riskLevel eq 'medium'" `
                -Select @('id', 'appId', 'displayName', 'servicePrincipalType', 'riskLevel', 'riskState', 'riskDetail', 'riskLastUpdatedDateTime')
        )
    } catch {
        if ($_.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }
        throw
    }

    # Disabled service principals are still reported. Disabling only blocks sign-ins: the risk stays open
    # until an admin dismisses or confirms it, and an admin can still do that while the app is disabled.
    # riskyServicePrincipal.isEnabled is not used because it can lag the service principal's real state.
    $Unremediated = @(
        $MediumRiskServicePrincipals | Where-Object { $UnremediatedStates -contains [string]$_.riskState }
    )
    Write-Verbose "Found $($MediumRiskServicePrincipals.Count) medium-risk service principal(s); $($Unremediated.Count) unremediated."

    if ($Unremediated.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            'Well done. No medium-risk service principals are left unremediated in Entra ID Protection.'
        )
        return $true
    }

    # Service principals at risk that hold a privileged role are listed first with their roles, as MT.1262 does
    # for users. Roles are only read when there is something to report. If the lookup fails, the
    # unremediated service principals are still reported, with a note.
    $PrivilegedRolesBySp = @{}
    $RoleNote = ''
    try {
        $RoleDefinitions = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'roleManagement/directory/roleDefinitions' `
                -Select @('id', 'displayName')
        )
        $RoleDefLookup = @{}
        foreach ($Def in $RoleDefinitions) { $RoleDefLookup[[string]$Def.id] = $Def }

        # Same properties as MT.1209, MT.1210 and MT.1260 so the active assignments come from the Graph cache.
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
            if (!$PrivilegedRolesBySp.ContainsKey($PrincipalId)) {
                $PrivilegedRolesBySp[$PrincipalId] = [System.Collections.Generic.List[string]]::new()
            }
            $PrivilegedRolesBySp[$PrincipalId].Add($RoleName)
        }
    } catch {
        Write-Verbose "Could not read directory role assignments: $($_.Exception.Message)"
        $PrivilegedRolesBySp = @{}
        $RoleNote = "`n`nNote: Directory role assignments could not be read, so privileged service principals were not identified."
    }

    # Privileged service principals first, then by display name.
    $Sorted = @(
        $Unremediated | Sort-Object -Property @{ Expression = { -not $PrivilegedRolesBySp.ContainsKey([string]$_.id) } }, displayName
    )
    $PrivilegedCount = @($Unremediated | Where-Object { $PrivilegedRolesBySp.ContainsKey([string]$_.id) }).Count

    $Result = "Found $($Unremediated.Count) medium-risk service principal(s) with unremediated risk."
    if ($PrivilegedCount -gt 0) {
        $Result += " $PrivilegedCount of them hold a privileged directory role and are listed first."
    }
    $Result += "`n`n| Service principal | Application ID | Type | Risk state | Risk detail | Risk last updated | Privileged role |"
    $Result += "`n| --- | --- | --- | --- | --- | --- | --- |"
    foreach ($Item in $Sorted) {
        $DisplayName = [string]$Item.displayName
        if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = '(unnamed)' }
        $Link = Get-MtLinkServicePrincipal -ServicePrincipal ([pscustomobject]@{ id = $Item.id; appId = $Item.appId; DisplayName = $DisplayName })
        $Type = Get-MtSafeMarkdown ([string]$Item.servicePrincipalType)
        $State = [string]$Item.riskState
        $Detail = Get-MtSafeMarkdown ([string]$Item.riskDetail)
        $Updated = if ($Item.riskLastUpdatedDateTime) {
            ($Item.riskLastUpdatedDateTime -as [datetime]).ToUniversalTime().ToString('yyyy-MM-dd')
        } else { 'Unknown' }
        $Roles = if ($PrivilegedRolesBySp.ContainsKey([string]$Item.id)) {
            Get-MtSafeMarkdown ($PrivilegedRolesBySp[[string]$Item.id] -join ', ')
        } else { 'None' }
        $Result += "`n| $Link | $($Item.appId) | $Type | $State | $Detail | $Updated | $Roles |"
    }
    $Result += $RoleNote

    # Each risky service principal also appears on the report's Affected objects page; the table above stays as it is.
    # There is no GraphObjectType for service principals, so the type comes from @odata.type.
    $AffectedServicePrincipals = @(
        $Sorted | ForEach-Object {
            [pscustomobject]@{ id = [string]$_.id; displayName = [string]$_.displayName; '@odata.type' = '#microsoft.graph.servicePrincipal' }
        }
    )
    Add-MtTestResultDetail -Result $Result -GraphObjects $AffectedServicePrincipals
    return $false
}
