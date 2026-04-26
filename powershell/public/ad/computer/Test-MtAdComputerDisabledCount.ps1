function Test-MtAdComputerDisabledCount {
    <#
    .SYNOPSIS
    Counts the number of disabled computer objects in Active Directory.

    .DESCRIPTION
    This test retrieves the count of disabled computer objects and compares it to the total
    number of computer objects in Active Directory. This provides visibility into the
    number of inactive or decommissioned computer accounts that remain in the directory.

    .EXAMPLE
    Test-MtAdComputerDisabledCount

    Returns $true if computer object data is accessible, $false otherwise.
    The test result includes counts of disabled and total computers.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerDisabledCount
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

    # Count disabled and total computers
    $disabledComputers = $computers | Where-Object { $_.Enabled -eq $false }
    $disabledCount = ($disabledComputers | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count
    $enabledCount = $totalCount - $disabledCount

    # Test passes if we successfully retrieved computer data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($disabledCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Computers | $totalCount |`n"
        $result += "| Enabled Computers | $enabledCount |`n"
        $result += "| Disabled Computers | $disabledCount |`n"
        $result += "| Disabled Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory computer objects have been analyzed. $disabledCount out of $totalCount computers ($percentage%) are disabled.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


