function Test-MtAdSiteWithoutDcDetails {
    <#
    .SYNOPSIS
    Lists the Active Directory sites without domain controllers.

    .DESCRIPTION
    This test provides detailed information about sites that do not have any
    domain controllers deployed. This helps identify locations that may
    experience authentication delays due to WAN-based authentication.

    .EXAMPLE
    Test-MtAdSiteWithoutDcDetails

    Returns $true if site and DC data is accessible.
    The test result includes detailed information about sites without DCs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSiteWithoutDcDetails
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

    # Test passes if we successfully retrieved data
    $testResult = $totalSites -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Sites | $totalSites |`n"
        $result += "| Sites without DCs | $sitesWithoutDcCount |`n"

        if ($sitesWithoutDcCount -gt 0) {
            $result += "`n### Sites Without Domain Controllers`n`n"
            $result += "| Site Name | Description |`n"
            $result += "| --- | --- |`n"

            foreach ($site in ($sitesWithoutDCs | Sort-Object Name)) {
                $description = if ($site.Description) { $site.Description } else { "N/A" }
                $result += "| $($site.Name) | $description |`n"
            }
        } else {
            $result += "`n✅ All sites have domain controllers deployed.`n"
        }

        $testResultMarkdown = "Active Directory sites without domain controllers have been analyzed.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory site information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
