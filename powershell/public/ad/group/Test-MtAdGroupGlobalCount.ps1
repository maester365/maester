function Test-MtAdGroupGlobalCount {
    <#
    .SYNOPSIS
    Counts the number of global groups in Active Directory.

    .DESCRIPTION
    This test counts global groups in Active Directory. Global groups can be used across
    the entire forest and can contain users and other global groups from the same domain.
    They are typically used to organize users by role, department, or function and can
    be placed into domain local groups for resource access. Global groups replicate
    only within their domain and are the most commonly used group scope for user organization.

    .EXAMPLE
    Test-MtAdGroupGlobalCount

    Returns $true if group data is accessible, $false otherwise.
    The test result includes counts of global groups.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupGlobalCount
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

    # Count global groups (GroupScope = "Global")
    $globalGroups = $groups | Where-Object { $_.GroupScope -eq "Global" }
    $globalCount = ($globalGroups | Measure-Object).Count
    $totalCount = ($groups | Measure-Object).Count

    # Test passes if we successfully retrieved group data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($globalCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Groups | $totalCount |`n"
        $result += "| Global Groups | $globalCount |`n"
        $result += "| Global Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory group objects have been analyzed. $globalCount out of $totalCount groups ($percentage%) are global groups (forest-wide usage).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory group objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


