function Test-MtAdSiteTotalCount {
    <#
    .SYNOPSIS
    Counts the total number of Active Directory sites.

    .DESCRIPTION
    This test retrieves the total count of sites configured in Active Directory.
    Sites represent physical geographic locations in your network topology and are
    fundamental to Active Directory replication and authentication efficiency.

    .EXAMPLE
    Test-MtAdSiteTotalCount

    Returns $true if site data is accessible.
    The test result includes the total count of sites.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSiteTotalCount
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
    $siteCount = ($sites | Measure-Object).Count

    # Test passes if we successfully retrieved site data
    $testResult = $siteCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Sites | $siteCount |`n"

        if ($siteCount -gt 0) {
            $siteNames = $sites | Select-Object -ExpandProperty Name | Sort-Object
            $result += "| Site Names | $($siteNames -join ', ') |`n"
        }

        $testResultMarkdown = "Active Directory sites have been analyzed. There are $siteCount site(s) configured in the domain.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory site information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


