function Test-MtAdGroupWithManagerCount {
    <#
    .SYNOPSIS
    Counts groups that have a manager assigned via the ManagedBy attribute.

    .DESCRIPTION
    This test identifies groups that have the ManagedBy attribute populated.
    The ManagedBy attribute specifies the user or group responsible for managing the group.
    While not all groups require a manager, having managers assigned can help with:
    - Accountability for group membership changes
    - Delegation of group management responsibilities
    - Better governance and lifecycle management

    .EXAMPLE
    Test-MtAdGroupWithManagerCount

    Returns $true if group data is accessible, $false otherwise.
    The test result includes the count of groups with managers assigned.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupWithManagerCount
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

    # Count groups with a manager assigned
    $groupsWithManager = $groups | Where-Object {
        $null -ne $_.ManagedBy -and $_.ManagedBy -ne ''
    }

    $managerCount = ($groupsWithManager | Measure-Object).Count
    $totalCount = ($groups | Measure-Object).Count
    $noManagerCount = $totalCount - $managerCount

    # Test passes if we successfully retrieved group data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($managerCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Groups | $totalCount |`n"
        $result += "| Groups with Manager | $managerCount |`n"
        $result += "| Groups without Manager | $noManagerCount |`n"
        $result += "| Managed Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory groups have been analyzed. $managerCount out of $totalCount groups ($percentage%) have a manager assigned.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory groups. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
