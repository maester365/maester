function Test-MtAdSiteWithoutSubnetDetails {
    <#
    .SYNOPSIS
    Lists the Active Directory sites without subnet associations.

    .DESCRIPTION
    This test provides detailed information about sites that do not have any
    subnets assigned to them. Sites without subnets cannot be used for
    client site assignment, which may result in clients authenticating to
    incorrect domain controllers.

    .EXAMPLE
    Test-MtAdSiteWithoutSubnetDetails

    Returns $true if site and subnet data is accessible.
    The test result includes detailed information about sites without subnets.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSiteWithoutSubnetDetails
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

    # Test passes if we successfully retrieved data
    $testResult = $totalSites -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Sites | $totalSites |`n"
        $result += "| Sites without Subnets | $sitesWithoutSubnetCount |`n"

        if ($sitesWithoutSubnetCount -gt 0) {
            $result += "`n### Sites Without Subnet Associations`n`n"
            $result += "| Site Name | Description |`n"
            $result += "| --- | --- |`n"

            foreach ($site in ($sitesWithoutSubnets | Sort-Object Name)) {
                $description = if ($site.Description) { $site.Description } else { "N/A" }
                $result += "| $($site.Name) | $description |`n"
            }

            $result += "`n> **Note:** Sites without subnets cannot be used for client site assignment. Consider assigning subnets or removing unused sites.`n"
        } else {
            $result += "`n✅ All sites have subnet associations configured.`n"
        }

        $testResultMarkdown = "Active Directory sites without subnet associations have been analyzed.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory site information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}



