function Test-MtCaMicrosoftManagedPolicyReportOnly {
    <#
    .SYNOPSIS
    Checks for Microsoft-managed Conditional Access policies that are still in report-only mode.

    .DESCRIPTION
    Microsoft creates Microsoft-managed Conditional Access policies in report-only mode and turns them on
    automatically no less than 30 days later, unless an administrator sets them to On or Off first. This check
    lists every Microsoft-managed policy that is still in report-only mode, with the earliest date Microsoft can
    turn it on, so an administrator can review its impact and decide before Microsoft does.

    Microsoft-managed policies are identified by the name prefix "Microsoft-managed:". Microsoft assigns this
    name and administrators cannot rename a Microsoft-managed policy. This is a name match, so if a customer
    named their own policy with the same prefix, it would also be listed.

    Learn more:
    https://learn.microsoft.com/entra/identity/conditional-access/managed-policies

    .EXAMPLE
    Test-MtCaMicrosoftManagedPolicyReportOnly

    .LINK
    https://maester.dev/docs/commands/Test-MtCaMicrosoftManagedPolicyReportOnly
    #>
    [MaesterTest(
        Id = 'MT.1224',
        Title = 'Microsoft-managed Conditional Access policies should not be left in report-only mode.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'access-control',
        ResourceType = 'ConditionalAccessPolicy',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = 'nist-800-53-r5:CM-3',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'Dfrank77'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Days Microsoft keeps a new Microsoft-managed policy in report-only mode before it can turn it on.
        [ValidateRange(1, 365)]
        [int] $EvaluationPeriodDays = 30
    )

    $ManagedPolicies = @(
        Get-MtConditionalAccessPolicy | Where-Object { $_.displayName -like 'Microsoft-managed:*' } |
            Sort-Object -Property displayName
    )
    if ($ManagedPolicies.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }

    $Today = (Get-Date).ToUniversalTime().Date
    $PendingPolicies = @($ManagedPolicies | Where-Object { $_.state -eq 'enabledForReportingButNotEnforced' })

    if ($PendingPolicies.Count -eq 0) {
        $Result = 'Well done. No Microsoft-managed Conditional Access policy is waiting in report-only mode.'
        $Result += "`n`n| Policy | State |`n| --- | --- |"
        foreach ($Policy in $ManagedPolicies) {
            $State = switch ($Policy.state) {
                'enabled' { 'On' }
                'disabled' { 'Off' }
                default { $Policy.state }
            }
            $Result += "`n| $(Get-MtManagedPolicyLink -Policy $Policy) | $State |"
        }
        Add-MtTestResultDetail -Result $Result
        return $true
    }

    $Result = "$($PendingPolicies.Count) Microsoft-managed Conditional Access " +
        "$(if ($PendingPolicies.Count -eq 1) { 'policy is' } else { 'policies are' }) still in report-only mode. " +
        'Microsoft turns Microsoft-managed policies on automatically unless an administrator sets them to On or Off. ' +
        'Review the impact of each policy, then choose.'
    $Result += "`n`n| Policy | Created | Microsoft can turn it on from | Status | Grant controls |"
    $Result += "`n| --- | --- | --- | --- | --- |"
    foreach ($Policy in $PendingPolicies) {
        $Created = $null
        if ($Policy.createdDateTime -is [datetime]) {
            $Created = $Policy.createdDateTime.ToUniversalTime().Date
        } elseif ($Policy.createdDateTime) {
            $Created = [datetimeoffset]::Parse(
                [string]$Policy.createdDateTime, [System.Globalization.CultureInfo]::InvariantCulture
            ).UtcDateTime.Date
        }

        if ($Created) {
            $EarliestOn = $Created.AddDays($EvaluationPeriodDays)
            $CreatedText = $Created.ToString('yyyy-MM-dd')
            $EarliestOnText = $EarliestOn.ToString('yyyy-MM-dd')
            $DaysLeft = [int]($EarliestOn - $Today).TotalDays
            if ($DaysLeft -gt 0) {
                $Status = "$DaysLeft day$(if ($DaysLeft -ne 1) { 's' }) left"
            } else {
                $Status = 'Due: Microsoft can turn it on at any time'
            }
        } else {
            $CreatedText = 'Unknown'
            $EarliestOnText = 'Unknown'
            $Status = 'Unknown'
        }

        $Grant = $Policy.grantControls
        $Controls = @($Grant.builtInControls | Where-Object { $_ })
        if ($Grant.authenticationStrength.displayName) {
            $Controls += "authentication strength: $($Grant.authenticationStrength.displayName)"
        }
        if ($Controls.Count -eq 0) {
            $GrantText = 'None'
        } elseif ($Controls.Count -eq 1) {
            $GrantText = $Controls[0]
        } else {
            $GrantText = $Controls -join " $($Grant.operator) "
        }
        $GrantText = $GrantText -replace '\|', '\|'

        $Result += "`n| $(Get-MtManagedPolicyLink -Policy $Policy) | $CreatedText | $EarliestOnText | $Status | $GrantText |"
    }

    Add-MtTestResultDetail -Result $Result
    return $false
}
