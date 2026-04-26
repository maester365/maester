function Test-MtAdDcSiteCoverageCount {
    <#
    .SYNOPSIS
    Counts the number of Active Directory sites with domain controllers.

    .DESCRIPTION
    This test retrieves the count of sites that have at least one domain controller.
    Proper site coverage ensures that authentication and directory services are available
    across all geographic locations where your organization operates.

    .EXAMPLE
    Test-MtAdDcSiteCoverageCount

    Returns $true if site coverage data is accessible.
    The test result includes the count of sites with DCs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDcSiteCoverageCount
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

    $domainControllers = $adState.DomainControllers
    $sitesWithDCs = $domainControllers | Select-Object -ExpandProperty Site -Unique
    $siteCount = ($sitesWithDCs | Measure-Object).Count
    $totalSites = ($adState.ReplicationSites | Measure-Object).Count
    $dcCount = ($domainControllers | Measure-Object).Count

    # Test passes if we successfully retrieved DC data
    $testResult = $dcCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Sites with Domain Controllers | $siteCount |`n"
        $result += "| Total Sites in Domain | $totalSites |`n"
        $result += "| Total Domain Controllers | $dcCount |`n"

        if ($siteCount -gt 0) {
            $siteNames = $sitesWithDCs | Sort-Object
            $result += "| Site Names | $($siteNames -join ', ') |`n"
        }

        $testResultMarkdown = "Active Directory site coverage has been analyzed. Domain controllers are present in $siteCount out of $totalSites site(s).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve domain controller site information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


