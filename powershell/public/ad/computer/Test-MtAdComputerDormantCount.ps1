function Test-MtAdComputerDormantCount {
    <#
    .SYNOPSIS
    Counts the number of dormant computer objects in Active Directory.

    .DESCRIPTION
    This test identifies computer objects that have not logged on for more than 90 days.
    Dormant computers can represent security risks if they are still enabled and can be
    used for unauthorized access. This test provides visibility into stale computer accounts.

    .EXAMPLE
    Test-MtAdComputerDormantCount

    Returns $true if computer object data is accessible, $false otherwise.
    The test result includes counts of dormant computers (>90 days since last logon).

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerDormantCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $computers = $adState.Computers
    $thresholdDays = 90
    $thresholdDate = (Get-Date).AddDays(-$thresholdDays)

    # Count dormant computers (last logon > 90 days ago and still enabled)
    $dormantComputers = $computers | Where-Object {
        $_.Enabled -eq $true -and
        $_.lastLogonDate -and
        $_.lastLogonDate -lt $thresholdDate
    }

    $dormantCount = ($dormantComputers | Measure-Object).Count
    $enabledCount = ($computers | Where-Object { $_.Enabled -eq $true } | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count

    # Test passes if we successfully retrieved computer data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($enabledCount -gt 0) {
            [Math]::Round(($dormantCount / $enabledCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Computers | $totalCount |`n"
        $result += "| Enabled Computers | $enabledCount |`n"
        $result += "| Dormant Computers (>90 days) | $dormantCount |`n"
        $result += "| Dormant Percentage (of enabled) | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory computer objects have been analyzed. $dormantCount out of $enabledCount enabled computers ($percentage%) have not logged on for more than 90 days.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


