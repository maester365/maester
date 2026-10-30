function Test-MtEntraUnremediatedHighRiskUser {
    <#
    .SYNOPSIS
    Finds users that Entra ID Protection rates high risk and that nobody has remediated.
    .DESCRIPTION
    Entra ID Protection flags users it believes are compromised and assigns a risk level and a
    risk state. A flag only clears when someone remediates it (password reset) or an admin
    dismisses or confirms-safe it. This check reports users whose risk level is high and whose
    risk state still shows active, unremediated risk, so an admin can act on flags that have been
    left sitting. It reads risk only; it never changes a user's risk state.
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
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1078.004',
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

    $Result = "Found $($Unremediated.Count) high-risk user(s) with unremediated risk."
    $Result += "`n`n| User | User principal name | Risk state | Risk detail | Risk last updated |"
    $Result += "`n| --- | --- | --- | --- | --- |"
    foreach ($Item in $Unremediated) {
        $DisplayName = [string]$Item.userDisplayName
        if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = '(unnamed)' }
        $DisplayName = [System.Net.WebUtility]::HtmlEncode($DisplayName) -replace '\|', '&#124;'
        $Upn = [System.Net.WebUtility]::HtmlEncode([string]$Item.userPrincipalName) -replace '\|', '&#124;'
        $State = [string]$Item.riskState
        $Detail = [System.Net.WebUtility]::HtmlEncode([string]$Item.riskDetail) -replace '\|', '&#124;'
        $Updated = if ($Item.riskLastUpdatedDateTime) {
            ($Item.riskLastUpdatedDateTime -as [datetime]).ToUniversalTime().ToString('yyyy-MM-dd')
        } else { 'Unknown' }
        $Result += "`n| $DisplayName | $Upn | $State | $Detail | $Updated |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'High'
    return $false
}
