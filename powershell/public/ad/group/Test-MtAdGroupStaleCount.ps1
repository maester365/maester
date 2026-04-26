function Test-MtAdGroupStaleCount {
    <#
    .SYNOPSIS
    Counts groups that have not been modified since before 2020.

    .DESCRIPTION
    This test identifies groups that have not been modified since before January 1, 2020.
    Groups that haven't been modified for an extended period may represent:
    - Unused or obsolete groups that should be reviewed for deletion
    - Legacy configurations that may no longer be needed
    - Potential security risks from forgotten or undocumented group memberships

    .EXAMPLE
    Test-MtAdGroupStaleCount

    Returns $true if group data is accessible, $false otherwise.
    The test result includes the count of stale groups.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupStaleCount
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

    # Count groups last modified before 2020
    $cutoffDate = Get-Date -Year 2020 -Month 1 -Day 1
    $staleGroups = $groups | Where-Object {
        $_.modifyTimeStamp -and $_.modifyTimeStamp -lt $cutoffDate
    }

    $staleCount = ($staleGroups | Measure-Object).Count
    $totalCount = ($groups | Measure-Object).Count

    # Test passes if we successfully retrieved group data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($staleCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Groups | $totalCount |`n"
        $result += "| Groups Modified Before 2020 | $staleCount |`n"
        $result += "| Stale Percentage | $percentage% |`n"
        $result += "| Cutoff Date | 2020-01-01 |`n`n"

        $testResultMarkdown = "Active Directory groups have been analyzed. $staleCount out of $totalCount groups ($percentage%) have not been modified since before 2020.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory groups. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


