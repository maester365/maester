function Test-MtAdSiteWithoutSubnetCount {
    <#
    .SYNOPSIS
    Counts the number of Active Directory sites without subnet associations.

    .DESCRIPTION
    This test identifies sites that do not have any subnets assigned to them.
    Sites without subnets cannot be used for client site assignment, which
    may result in clients authenticating to incorrect DCs.

    .EXAMPLE
    Test-MtAdSiteWithoutSubnetCount

    Returns $true if site and subnet data is accessible.
    The test result includes the count of sites without subnets.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSiteWithoutSubnetCount
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
    $sitesWithSubnetNames = $sitesWithSubnets | ForEach-Object {
        # SiteObject is a DN like "CN=SiteName,CN=Sites,CN=Configuration,DC=..."
        ($_ -split ',')[0] -replace '^CN=', ''
    }

    # Get sites without subnets
    $sitesWithoutSubnets = $sites | Where-Object { $sitesWithSubnetNames -notcontains $_.Name }
    $sitesWithoutSubnetCount = ($sitesWithoutSubnets | Measure-Object).Count
    $totalSites = ($sites | Measure-Object).Count
    $sitesWithSubnetCount = $totalSites - $sitesWithoutSubnetCount

    # Test passes if we successfully retrieved data
    $testResult = $totalSites -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Sites | $totalSites |`n"
        $result += "| Sites with Subnets | $sitesWithSubnetCount |`n"
        $result += "| Sites without Subnets | $sitesWithoutSubnetCount |`n"

        if ($sitesWithoutSubnetCount -gt 0) {
            $percentage = [Math]::Round(($sitesWithoutSubnetCount / $totalSites) * 100, 2)
            $result += "| Sites without Subnets % | $percentage% |`n"

            $siteNames = $sitesWithoutSubnets | Select-Object -ExpandProperty Name | Sort-Object
            $result += "| Sites without Subnets | $($siteNames -join ', ') |`n"
        }

        $testResultMarkdown = "Active Directory site subnet associations have been analyzed. $sitesWithoutSubnetCount out of $totalSites site(s) do not have subnets assigned.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory site information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
