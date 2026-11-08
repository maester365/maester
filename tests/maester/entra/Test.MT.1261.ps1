function Test-MtEntraUnremediatedMediumRiskUser {
    <#
    .SYNOPSIS
    Finds users that Entra ID Protection rates medium risk and that nobody has remediated.

    .DESCRIPTION
    Entra ID Protection flags users it believes may be compromised and assigns a risk level and a
    risk state. A flag only clears when someone remediates it (password reset) or an admin
    dismisses or confirms-safe it. This check reports users whose risk level is medium and whose
    risk state still shows active, unremediated risk, so an admin can act on flags that have been
    left sitting. If a reported user holds a privileged directory role, it is listed first
    with its roles. It reads risk only; it never changes a user's risk state.

    .EXAMPLE
    Test-MtEntraUnremediatedMediumRiskUser

    .LINK
    https://maester.dev/docs/commands/Test-MtEntraUnremediatedMediumRiskUser

    .LINK
    https://learn.microsoft.com/graph/api/resources/riskyuser?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id = 'MT.1261',
        Title = 'Medium-risk users should not be left unremediated in Entra ID Protection.',
        Product = 'entra',
        Feature = 'identity-protection',
        Area = 'logging-and-detection',
        ResourceType = 'User',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1078.004',
        Control = ('nist-800-53-r5:AC-2(12)', 'nist-800-53-r5:IR-4'),
        Cloud = ('Commercial', 'GCC', 'GCCHigh', 'DoD'),
        Service = 'Graph',
        License = 'AAD_PREMIUM_P2',
        Permission = ('Graph:Scope:IdentityRiskyUser.Read.All', 'Graph:Scope:RoleManagement.Read.Directory|Graph:Scope:RoleManagement.Read.All'),
        Lifecycle = 'Preview',
        Author = 'Dfrank77'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Deleted users stay in the risk report and admins cannot dismiss them, so they are not reported.
    # Active, unremediated risk states. A flag an admin has handled moves to 'remediated',
    # 'dismissed', 'confirmedSafe' or 'none'; those are intentionally excluded.
    # 'confirmedCompromised' MUST be treated as unremediated alongside 'atRisk' -- confirming a
    # user compromised does not clear the risk.
    $UnremediatedStates = @('atRisk', 'confirmedCompromised')

    Write-Verbose 'Reading medium-risk users from Entra ID Protection.'
    # Filter riskLevel server-side only. The riskState set is applied client-side on purpose:
    # Graph rejects some compound / 'or' / 'in' filter shapes on this endpoint, so a single-property
    # filter is the reliable shape, and the state list is tiny to post-filter.
    try {
        $MediumRiskUsers = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'identityProtection/riskyUsers' `
                -Filter "riskLevel eq 'medium'" `
                -Select @('id', 'isDeleted', 'userPrincipalName', 'userDisplayName', 'riskLevel', 'riskState', 'riskDetail', 'riskLastUpdatedDateTime')
        )
    } catch {
        if ($_.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }
        throw
    }

    $Unremediated = @(
        $MediumRiskUsers | Where-Object { $UnremediatedStates -contains [string]$_.riskState -and $_.isDeleted -ne $true }
    )
    Write-Verbose "Found $($MediumRiskUsers.Count) medium-risk user(s); $($Unremediated.Count) unremediated."

    if ($Unremediated.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            'Well done. No medium-risk users are left unremediated in Entra ID Protection.'
        )
        return $true
    }

    # Privileged users at risk are listed first with their roles (#2518). Roles are only read when
    # there is something to report, so a clean tenant makes no extra Graph calls. The role lookup is extra
    # detail: if it fails, the unremediated users are still reported, with a note.
    $PrivilegedRolesByUser = @{}
    $RoleNote = ''
    try {
        $PrivilegedResult = Get-MtPrincipalPrivilegedRole -PrincipalId @($Unremediated | ForEach-Object { [string]$_.id })
        $PrivilegedRolesByUser = $PrivilegedResult.RolesByPrincipal
        if (!$PrivilegedResult.EligibleChecked) {
            $RoleNote = "`n`nNote: PIM-eligible role assignments were not checked because they need " +
                'Microsoft Entra ID P2 or Governance. Only active role assignments were checked.'
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

    $Result = "Found $($Unremediated.Count) medium-risk user(s) with unremediated risk."
    if ($PrivilegedCount -gt 0) {
        $Result += " $PrivilegedCount of them hold a privileged directory role and are listed first."
    }
    $Result += "`n`n| User | User principal name | Risk state | Risk detail | Risk last updated | Privileged role |"
    $Result += "`n| --- | --- | --- | --- | --- | --- |"
    foreach ($Item in $Sorted) {
        $DisplayName = [string]$Item.userDisplayName
        if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = '(unnamed)' }
        $DisplayName = Get-MtSafeMarkdown $DisplayName
        $Upn = Get-MtSafeMarkdown ([string]$Item.userPrincipalName)
        $State = [string]$Item.riskState
        $Detail = Get-MtSafeMarkdown ([string]$Item.riskDetail)
        $Updated = if ($Item.riskLastUpdatedDateTime) {
            ($Item.riskLastUpdatedDateTime -as [datetime]).ToUniversalTime().ToString('yyyy-MM-dd')
        } else { 'Unknown' }
        $Roles = if ($PrivilegedRolesByUser.ContainsKey([string]$Item.id)) {
            Get-MtSafeMarkdown ($PrivilegedRolesByUser[[string]$Item.id] -join ', ')
        } else { 'None' }
        $Result += "`n| $DisplayName | $Upn | $State | $Detail | $Updated | $Roles |"
    }
    $Result += $RoleNote

    Add-MtTestResultDetail -Result $Result
    return $false
}
