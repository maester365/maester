function Test-MtAdComputerNonStandardGroup {
    <#
    .SYNOPSIS
    Counts computers with non-standard primary group IDs.

    .DESCRIPTION
    This test identifies computer objects that are not using standard primary group IDs.
    Standard computer primary groups are:
    - 515: Domain Computers
    - 516: Domain Controllers
    - 521: Read-only Domain Controllers

    Computers with non-standard primary groups may indicate misconfiguration or
    custom security configurations that should be reviewed.

    .EXAMPLE
    Test-MtAdComputerNonStandardGroup

    Returns $true if computer object data is accessible, $false otherwise.
    The test result includes the count of computers with non-standard primary groups.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerNonStandardGroup
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Standard computer primary group IDs
    $standardGroupIds = @(515, 516, 521)

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $computers = $adState.Computers

    # Count enabled computers with non-standard primary group
    $nonStandardGroupComputers = $computers | Where-Object {
        $_.Enabled -eq $true -and
        $_.primaryGroupId -and
        $_.primaryGroupId -notin $standardGroupIds
    }

    $nonStandardCount = ($nonStandardGroupComputers | Measure-Object).Count
    $enabledCount = ($computers | Where-Object { $_.Enabled -eq $true } | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count

    # Test passes if we successfully retrieved computer data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($enabledCount -gt 0) {
            [Math]::Round(($nonStandardCount / $enabledCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Computers | $totalCount |`n"
        $result += "| Enabled Computers | $enabledCount |`n"
        $result += "| Non-Standard Primary Group | $nonStandardCount |`n"
        $result += "| Non-Standard Percentage | $percentage% |`n`n"
        $result += "**Standard Primary Group IDs:** 515 (Domain Computers), 516 (Domain Controllers), 521 (Read-only Domain Controllers)`n`n"

        $testResultMarkdown = "Active Directory computer objects have been analyzed. $nonStandardCount out of $enabledCount enabled computers ($percentage%) have non-standard primary group IDs.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


