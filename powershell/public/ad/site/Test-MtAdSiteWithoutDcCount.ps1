function Test-MtAdSiteWithoutDcCount {
    <#
    .SYNOPSIS
    Counts the number of Active Directory sites without domain controllers.

    .DESCRIPTION
    This test identifies sites that do not have any domain controllers deployed.
    Sites without DCs may experience authentication delays as clients must
    authenticate across the WAN to another site.

    .EXAMPLE
    Test-MtAdSiteWithoutDcCount

    Returns $true if site and DC data is accessible.
    The test result includes the count of sites without DCs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSiteWithoutDcCount
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
    $domainControllers = $adState.DomainControllers

    # Get sites with DCs
    $sitesWithDCs = $domainControllers | Select-Object -ExpandProperty Site -Unique

    # Get sites without DCs
    $sitesWithoutDCs = $sites | Where-Object { $sitesWithDCs -notcontains $_.Name }
    $sitesWithoutDcCount = ($sitesWithoutDCs | Measure-Object).Count
    $totalSites = ($sites | Measure-Object).Count
    $sitesWithDcCount = $totalSites - $sitesWithoutDcCount

    # Test passes if we successfully retrieved data
    $testResult = $totalSites -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Sites | $totalSites |`n"
        $result += "| Sites with DCs | $sitesWithDcCount |`n"
        $result += "| Sites without DCs | $sitesWithoutDcCount |`n"

        if ($sitesWithoutDcCount -gt 0) {
            $percentage = [Math]::Round(($sitesWithoutDcCount / $totalSites) * 100, 2)
            $result += "| Sites without DCs % | $percentage% |`n"

            $siteNames = $sitesWithoutDCs | Select-Object -ExpandProperty Name | Sort-Object
            $result += "| Sites without DCs | $($siteNames -join ', ') |`n"
        }

        $testResultMarkdown = "Active Directory site coverage has been analyzed. $sitesWithoutDcCount out of $totalSites site(s) do not have domain controllers.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory site information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
