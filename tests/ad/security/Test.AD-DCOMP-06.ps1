function Test-MtAdComputerStaleEnabledCount {
    <#
    .SYNOPSIS
    Identifies enabled computers that have not logged on for the configured threshold or more.

    .DESCRIPTION
    Stale enabled computer accounts represent a security risk as they can be
    compromised and reactivated by attackers. This test identifies enabled
    computers that have not authenticated to the domain for the configured threshold or more.

    Because nearly every domain has at least one stale enabled computer, this
    test returns an Investigate result (rather than Pass/Fail) so the count
    and details are surfaced for review without causing a failing audit.

    Security Risk:
    - Stale enabled accounts can be reactivated and used for lateral movement
    - May indicate decommissioned systems that were never properly disabled
    - Can be targeted for compromise without detection
    - Should be disabled or removed after verification

    .EXAMPLE
    Test-MtAdComputerStaleEnabledCount

    Returns the count of stale enabled computers and lists details for review.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerStaleEnabledCount
    #>
    [MaesterTest(
        Id = 'AD-DCOMP-06',
        Title = 'No enabled computers should be stale beyond the configured threshold',
        Product = 'ad',
        Feature = 'computers',
        Area = 'identity-lifecycle',
        ResourceType = 'Computer',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.002',
        Control = 'nist-800-53-r5:AC-2(3)',
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Number of days without a logon before an enabled computer is considered stale.
        [ValidateRange(1, 3650)] [int] $StaleThresholdDays = 180
    )

    Write-Verbose "Starting Test-MtAdComputerStaleEnabledCount"
    $adState = Get-MtADDomainState -Categories @('Computers')
    Write-Verbose "Retrieved AD state"

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting computer stale enabled count"

    $computers = $adState.Computers
    if ($null -eq $computers) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    $staleThreshold = (Get-Date).AddDays(-$StaleThresholdDays)

    # Find enabled computers that haven't logged on for the configured threshold or more.
    $staleEnabledComputers = $computers | Where-Object {
        $_.Enabled -eq $true -and
        ($null -eq $_.lastLogonDate -or $_.lastLogonDate -lt $staleThreshold)
    }

    $staleCount = ($staleEnabledComputers | Measure-Object).Count
    $enabledComputers = @($computers | Where-Object { $_.Enabled -eq $true })
    $totalEnabled = $enabledComputers.Count
    $neverLoggedOn = ($staleEnabledComputers | Where-Object { $null -eq $_.lastLogonDate } | Measure-Object).Count
    $notLoggedInThresholdDays = $staleCount - $neverLoggedOn

    $mostRecentLogon = 'No enabled computers have logged on'
    $loggedOnEnabledComputers = @($enabledComputers | Where-Object { $null -ne $_.lastLogonDate })
    if ($loggedOnEnabledComputers.Count -gt 0) {
        $mostRecentLogon = ($loggedOnEnabledComputers | Sort-Object -Property lastLogonDate -Descending | Select-Object -First 1).lastLogonDate.ToString('yyyy-MM-dd')
    }


    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Enabled Computers | $totalEnabled |" + "`n"
    $result += "| Stale Enabled Computers ($StaleThresholdDays+ days) | $staleCount |" + "`n"
    $result += "| Never Logged On | $neverLoggedOn |" + "`n"
    $result += "| Not Logged On in $StaleThresholdDays+ Days | $notLoggedInThresholdDays |" + "`n"

    if ($totalEnabled -gt 0) {
        $percentage = [Math]::Round(($staleCount / $totalEnabled) * 100, 2)
        $result += "| Stale Percentage | $percentage% |" + "`n"
    }

    if ($staleCount -gt 0) {
        $result += "`n**Stale Enabled Computers (Top 10):**" + "`n" + "`n"
        $result += "| Computer Name | Last Logon | Operating System |" + "`n"
        $result += "| --- | --- | --- |" + "`n"

        $sortedStale = $staleEnabledComputers | Sort-Object -Property lastLogonDate | Select-Object -First 10
        foreach ($comp in $sortedStale) {
            $lastLogon = if ($comp.lastLogonDate) { $comp.lastLogonDate.ToString('yyyy-MM-dd') } else { 'Never' }
            $result += "| $($comp.Name) | $lastLogon | $($comp.operatingSystem) |" + "`n"
        }

        if ($staleCount -gt 10) {
            $result += "| ... and $($staleCount - 10) more | | |" + "`n"
        }
    }
    Write-Verbose "Counts computed"

    if ($staleCount -eq 0) {
        $analysisSummary = "There are $totalEnabled enabled computers. The most recent logon date is $mostRecentLogon. No enabled computers currently exceed the stale threshold of $StaleThresholdDays days. A computer would trigger the threshold if it has never logged on or last logged on before $($staleThreshold.ToString('yyyy-MM-dd'))."
        $testResultMarkdown = "$analysisSummary`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        Add-MtTestResultDetail -Result $testResultMarkdown
        Write-Verbose "Completed Test-MtAdComputerStaleEnabledCount"
        return $true
    } else {
        $testResultMarkdown = "Stale enabled computer accounts have been identified. These should be reviewed and disabled if no longer needed.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
        Write-Verbose "Completed Test-MtAdComputerStaleEnabledCount"
        return $null
    }
}
