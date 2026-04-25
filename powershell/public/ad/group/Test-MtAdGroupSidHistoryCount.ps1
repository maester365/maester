function Test-MtAdGroupSidHistoryCount {
    <#
    .SYNOPSIS
    Counts groups with SID History set in Active Directory.

    .DESCRIPTION
    This test identifies group objects that have SID History attributes populated.
    SID History is typically used during domain migrations to maintain access to resources
    in the source domain. Groups with SID History may indicate:
    - Migrated group accounts from previous domains
    - Potential security concerns if SID History contains SIDs from untrusted domains
    - Legacy configurations that should be reviewed and cleaned up

    .EXAMPLE
    Test-MtAdGroupSidHistoryCount

    Returns $true if group data is accessible, $false otherwise.
    The test result includes the count of groups with SID History.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupSidHistoryCount
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

    $groups = $adState.Groups

    # Count groups with SID History
    $groupsWithSidHistory = $groups | Where-Object {
        $_.SIDHistory -and
        ($_.SIDHistory | Measure-Object).Count -gt 0
    }

    $sidHistoryCount = ($groupsWithSidHistory | Measure-Object).Count
    $totalCount = ($groups | Measure-Object).Count

    # Test passes if we successfully retrieved group data
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
        $result += "| Total Groups | $totalCount |`n"
        $result += "| Groups with SID History | $sidHistoryCount |`n"
        $result += "| SID History Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory groups have been analyzed. $sidHistoryCount out of $totalCount groups ($percentage%) have SID History set.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory groups. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
