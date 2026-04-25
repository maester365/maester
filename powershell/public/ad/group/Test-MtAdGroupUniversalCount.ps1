function Test-MtAdGroupUniversalCount {
    <#
    .SYNOPSIS
    Counts the number of universal groups in Active Directory.

    .DESCRIPTION
    This test counts universal groups in Active Directory. Universal groups can be used
    across the entire forest and can contain users and other groups from any domain
    in the forest. Unlike global groups, universal groups are stored in the Global
    Catalog, which means membership changes trigger forest-wide replication. They are
    typically used in multi-domain environments to provide consistent access across domains
    or to nest global groups from multiple domains into a single group for resource access.

    .EXAMPLE
    Test-MtAdGroupUniversalCount

    Returns $true if group data is accessible, $false otherwise.
    The test result includes counts of universal groups.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupUniversalCount
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

    # Count universal groups (GroupScope = "Universal")
    $universalGroups = $groups | Where-Object { $_.GroupScope -eq "Universal" }
    $universalCount = ($universalGroups | Measure-Object).Count
    $totalCount = ($groups | Measure-Object).Count

    # Test passes if we successfully retrieved group data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($universalCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Groups | $totalCount |`n"
        $result += "| Universal Groups | $universalCount |`n"
        $result += "| Universal Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory group objects have been analyzed. $universalCount out of $totalCount groups ($percentage%) are universal groups (forest-wide, stored in Global Catalog).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory group objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
