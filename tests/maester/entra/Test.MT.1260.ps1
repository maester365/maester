function Test-MtEntraUnremediatedHighRiskUser {
    <#
    .SYNOPSIS
    Finds users that Entra ID Protection rates high risk and that nobody has remediated.
    .DESCRIPTION
    Entra ID Protection flags users it believes are compromised and assigns a risk level and a
    risk state. A flag only clears when someone remediates it (password reset) or an admin
    dismisses or confirms-safe it. This check reports users whose risk level is high and whose
    risk state still shows active, unremediated risk, so an admin can act on flags that have been
    left sitting. If a reported user holds a privileged directory role, the severity is raised to
    High. It reads risk only; it never changes a user's risk state.
    .EXAMPLE
    Test-MtEntraUnremediatedHighRiskUser
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraUnremediatedHighRiskUser
    .LINK
    https://learn.microsoft.com/graph/api/resources/riskyuser?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id = 'MT.1260',
        Title = 'High-risk users should not be left unremediated in Entra ID Protection.',
        Product = 'entra',
        Feature = 'identity-protection',
        Area = 'logging-and-detection',
        ResourceType = 'User',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1078.004',
        Control = ('nist-800-53-r5:AC-2(12)', 'nist-800-53-r5:IR-4'),
        Service = 'Graph',
        License = 'AAD_PREMIUM_P2',
        Permission = 'Graph:Scope:IdentityRiskyUser.Read.All',
        Lifecycle = 'Preview',
        Author = 'Dfrank77'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Active, unremediated risk states. A flag an admin has handled moves to 'remediated',
    # 'dismissed', 'confirmedSafe' or 'none'; those are intentionally excluded.
    # 'confirmedCompromised' MUST be treated as unremediated alongside 'atRisk' -- confirming a
    # user compromised does not clear the risk, and the confirmCompromised API (the documented
    # way to simulate risk for testing) lands users in exactly this state.
    $UnremediatedStates = @('atRisk', 'confirmedCompromised')

    Write-Verbose 'Reading high-risk users from Entra ID Protection.'
    # Filter riskLevel server-side only. The riskState set is applied client-side on purpose:
    # Graph rejects some compound / 'or' / 'in' filter shapes on this endpoint, so a single-property
    # filter is the reliable shape, and the state list is tiny to post-filter.
    try {
        $HighRiskUsers = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'identityProtection/riskyUsers' `
                -Filter "riskLevel eq 'high'" `
                -Select @('id', 'userPrincipalName', 'userDisplayName', 'riskLevel', 'riskState', 'riskDetail', 'riskLastUpdatedDateTime')
        )
    } catch {
        if ($_.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }
        throw
    }

    $Unremediated = @(
        $HighRiskUsers | Where-Object { $UnremediatedStates -contains [string]$_.riskState }
    )
    Write-Verbose "Found $($HighRiskUsers.Count) high-risk user(s); $($Unremediated.Count) unremediated."

    if ($Unremediated.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            'Well done. No high-risk users are left unremediated in Entra ID Protection.'
        )
        return $true
    }

    # Privileged users at risk raise severity to High (#2518). Roles are only read when there is
    # something to report, so a clean tenant makes no extra Graph calls. The role lookup is extra
    # detail: if it fails, the unremediated users are still reported, with a note.
    $PrivilegedRolesByUser = @{}
    $RoleNote = ''
    try {
        $RoleDefinitions = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'roleManagement/directory/roleDefinitions' `
                -Select @('id', 'displayName')
        )
        $RoleDefLookup = @{}
        foreach ($Def in $RoleDefinitions) { $RoleDefLookup[[string]$Def.id] = $Def }

        # Same properties as MT.1209 and MT.1210 so the active assignments come from the Graph cache.
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
            # isPrivileged is not queryable on roleDefinitions; use Maester's role catalog, as MT.1210 does.
            $RoleInfo = Get-MtRoleInfo -RoleName ([string]$RoleDef.displayName -replace '\s', '')
            if ($null -eq $RoleInfo -or !$RoleInfo.IsPrivileged) { continue }
            $RoleName = [string]$RoleDef.displayName
            if ($Assignment.AssignmentType -eq 'Eligible') { $RoleName += ' (eligible)' }
            if (!$PrivilegedRolesByUser.ContainsKey($PrincipalId)) {
                $PrivilegedRolesByUser[$PrincipalId] = [System.Collections.Generic.List[string]]::new()
            }
            $PrivilegedRolesByUser[$PrincipalId].Add($RoleName)
        }
    } catch {
        Write-Verbose "Could not read directory role assignments: $($_.Exception.Message)"
        $PrivilegedRolesByUser = @{}
        $RoleNote = "`n`nNote: Directory role assignments could not be read, so privileged users were not identified."
    }

    # Privileged users first, then by user principal name.
    $Sorted = @(
        $Unremediated | Sort-Object -Property @{ Expression = { -not $PrivilegedRolesByUser.ContainsKey([string]$_.id) } }, userPrincipalName
    )
    $PrivilegedCount = @($Unremediated | Where-Object { $PrivilegedRolesByUser.ContainsKey([string]$_.id) }).Count

    $Result = "Found $($Unremediated.Count) high-risk user(s) with unremediated risk."
    if ($PrivilegedCount -gt 0) {
        $Result += " $PrivilegedCount of them hold a privileged directory role, so severity is raised to High."
    }
    $Result += "`n`n| User | User principal name | Risk state | Risk detail | Risk last updated | Privileged role |"
    $Result += "`n| --- | --- | --- | --- | --- | --- |"
    foreach ($Item in $Sorted) {
        $DisplayName = [string]$Item.userDisplayName
        if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = '(unnamed)' }
        $DisplayName = [System.Net.WebUtility]::HtmlEncode($DisplayName) -replace '\|', '&#124;'
        $Upn = [System.Net.WebUtility]::HtmlEncode([string]$Item.userPrincipalName) -replace '\|', '&#124;'
        $State = [string]$Item.riskState
        $Detail = [System.Net.WebUtility]::HtmlEncode([string]$Item.riskDetail) -replace '\|', '&#124;'
        $Updated = if ($Item.riskLastUpdatedDateTime) {
            ($Item.riskLastUpdatedDateTime -as [datetime]).ToUniversalTime().ToString('yyyy-MM-dd')
        } else { 'Unknown' }
        $Roles = if ($PrivilegedRolesByUser.ContainsKey([string]$Item.id)) {
            [System.Net.WebUtility]::HtmlEncode(($PrivilegedRolesByUser[[string]$Item.id] -join ', ')) -replace '\|', '&#124;'
        } else { 'None' }
        $Result += "`n| $DisplayName | $Upn | $State | $Detail | $Updated | $Roles |"
    }
    $Result += $RoleNote

    if ($PrivilegedCount -gt 0) {
        Add-MtTestResultDetail -Result $Result -Severity 'High'
    } else {
        Add-MtTestResultDetail -Result $Result
    }
    return $false
}
