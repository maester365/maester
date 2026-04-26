function Test-MtAdComputerSidHistoryCount {
    <#
    .SYNOPSIS
    Counts computers with SID History set.

    .DESCRIPTION
    This test identifies computer objects that have SID History attributes populated.
    SID History is typically used during domain migrations to maintain access to resources
    in the source domain. Computers with SID History may indicate:
    - Migrated computer accounts
    - Potential security concerns if SID History contains SIDs from untrusted domains
    - Legacy configurations that should be reviewed

    .EXAMPLE
    Test-MtAdComputerSidHistoryCount

    Returns $true if computer object data is accessible, $false otherwise.
    The test result includes the count of computers with SID History.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerSidHistoryCount
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

    # Count computers with SID History
    $computersWithSidHistory = $computers | Where-Object {
        $_.SIDHistory -and
        ($_.SIDHistory | Measure-Object).Count -gt 0
    }

    $sidHistoryCount = ($computersWithSidHistory | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count

    # Test passes if we successfully retrieved computer data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($sidHistoryCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Computers | $totalCount |`n"
        $result += "| Computers with SID History | $sidHistoryCount |`n"
        $result += "| SID History Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory computer objects have been analyzed. $sidHistoryCount out of $totalCount computers ($percentage%) have SID History set.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


