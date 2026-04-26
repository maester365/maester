function Test-MtAdComputerStaleEnabledCount {
    <#
    .SYNOPSIS
    Counts enabled computers that have not logged on for 180 days or more.

    .DESCRIPTION
    Stale enabled computer accounts represent a security risk as they can be
    compromised and reactivated by attackers. This test identifies enabled
    computers that have not authenticated to the domain for 180 days or more.

    Security Risk:
    - Stale enabled accounts can be reactivated and used for lateral movement
    - May indicate decommissioned systems that were never properly disabled
    - Can be targeted for compromise without detection
    - Should be disabled or removed after verification

    .EXAMPLE
    Test-MtAdComputerStaleEnabledCount

    Returns $true if computer data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerStaleEnabledCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $computers = $adState.Computers
    $staleThreshold = (Get-Date).AddDays(-180)

    # Find enabled computers that haven't logged on in 180+ days
    $staleEnabledComputers = $computers | Where-Object {
        $_.Enabled -eq $true -and
        ($null -eq $_.lastLogonDate -or $_.lastLogonDate -lt $staleThreshold)
    }

    $staleCount = ($staleEnabledComputers | Measure-Object).Count
    $totalEnabled = ($computers | Where-Object { $_.Enabled -eq $true } | Measure-Object).Count
    $neverLoggedOn = ($staleEnabledComputers | Where-Object { $null -eq $_.lastLogonDate } | Measure-Object).Count
    $notLoggedIn180Days = $staleCount - $neverLoggedOn

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Enabled Computers | $totalEnabled |`n"
    $result += "| Stale Enabled Computers (180+ days) | $staleCount |`n"
    $result += "| Never Logged On | $neverLoggedOn |`n"
    $result += "| Not Logged On in 180+ Days | $notLoggedIn180Days |`n"

    if ($totalEnabled -gt 0) {
        $percentage = [Math]::Round(($staleCount / $totalEnabled) * 100, 2)
        $result += "| Stale Percentage | $percentage% |`n"
    }

    if ($staleCount -gt 0) {
        $result += "`n**Stale Enabled Computers (Top 10):**`n`n"
        $result += "| Computer Name | Last Logon | Operating System |`n"
        $result += "| --- | --- | --- |`n"

        $sortedStale = $staleEnabledComputers | Sort-Object -Property lastLogonDate | Select-Object -First 10
        foreach ($comp in $sortedStale) {
            $lastLogon = if ($comp.lastLogonDate) { $comp.lastLogonDate.ToString('yyyy-MM-dd') } else { 'Never' }
            $result += "| $($comp.Name) | $lastLogon | $($comp.operatingSystem) |`n"
        }

        if ($staleCount -gt 10) {
            $result += "| ... and $($staleCount - 10) more | | |`n"
        }
    }

    $testResultMarkdown = "Stale enabled computer accounts have been identified. These should be reviewed and disabled if no longer needed.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}




