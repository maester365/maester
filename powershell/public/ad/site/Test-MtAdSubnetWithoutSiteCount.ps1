function Test-MtAdSubnetWithoutSiteCount {
    <#
    .SYNOPSIS
    Counts the number of subnets without site associations.

    .DESCRIPTION
    This test identifies subnets that are not assigned to any site.
    Orphaned subnets cannot be used for client site assignment and
    may indicate incomplete configuration or stale data.

    .EXAMPLE
    Test-MtAdSubnetWithoutSiteCount

    Returns $true if subnet data is accessible.
    The test result includes the count of subnets without site associations.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSubnetWithoutSiteCount
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

    $subnets = $adState.Subnets
    $totalSubnets = ($subnets | Measure-Object).Count

    # Get subnets without site associations
    $subnetsWithoutSite = $subnets | Where-Object { -not $_.SiteObject }
    $subnetsWithoutSiteCount = ($subnetsWithoutSite | Measure-Object).Count
    $subnetsWithSiteCount = $totalSubnets - $subnetsWithoutSiteCount

    # Test passes if we successfully retrieved data
    $testResult = $totalSubnets -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Subnets | $totalSubnets |`n"
        $result += "| Subnets with Site | $subnetsWithSiteCount |`n"
        $result += "| Subnets without Site | $subnetsWithoutSiteCount |`n"

        if ($subnetsWithoutSiteCount -gt 0) {
            $percentage = [Math]::Round(($subnetsWithoutSiteCount / $totalSubnets) * 100, 2)
            $result += "| Orphaned Subnets % | $percentage% |`n"

            $orphanedNames = $subnetsWithoutSite | Select-Object -ExpandProperty Name | Sort-Object
            $result += "| Orphaned Subnets | $($orphanedNames -join ', ') |`n"
            $result += "`n> **Warning:** Subnets without site associations cannot be used for client site assignment. Consider assigning them to appropriate sites or removing them.`n"
        }

        $testResultMarkdown = "Active Directory subnet site associations have been analyzed. $subnetsWithoutSiteCount subnet(s) are not associated with any site.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory subnet information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
