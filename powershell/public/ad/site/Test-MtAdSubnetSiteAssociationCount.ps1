function Test-MtAdSubnetSiteAssociationCount {
    <#
    .SYNOPSIS
    Counts the number of sites that have subnet associations.

    .DESCRIPTION
    This test identifies how many sites have subnets assigned to them.
    Sites with subnets can be used for client site assignment, ensuring
    clients authenticate to the nearest domain controller.

    .EXAMPLE
    Test-MtAdSubnetSiteAssociationCount

    Returns $true if site and subnet data is accessible.
    The test result includes the count of sites with subnet associations.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSubnetSiteAssociationCount
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

    $sites = $adState.ReplicationSites
    $subnets = $adState.Subnets

    # Get sites with subnets
    $sitesWithSubnets = $subnets | Where-Object { $_.SiteObject } | Select-Object -ExpandProperty SiteObject -Unique
    $sitesWithSubnetCount = ($sitesWithSubnets | Measure-Object).Count
    $totalSites = ($sites | Measure-Object).Count
    $sitesWithoutSubnetCount = $totalSites - $sitesWithSubnetCount

    # Test passes if we successfully retrieved data
    $testResult = $totalSites -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Sites | $totalSites |`n"
        $result += "| Sites with Subnets | $sitesWithSubnetCount |`n"
        $result += "| Sites without Subnets | $sitesWithoutSubnetCount |`n"

        if ($sitesWithSubnetCount -gt 0 -and $totalSites -gt 0) {
            $percentage = [Math]::Round(($sitesWithSubnetCount / $totalSites) * 100, 2)
            $result += "| Sites with Subnets % | $percentage% |`n"
        }

        $testResultMarkdown = "Active Directory site subnet associations have been analyzed. $sitesWithSubnetCount out of $totalSites site(s) have subnets assigned.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory site information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


