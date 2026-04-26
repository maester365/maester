function Test-MtAdSmtpSiteLinksCount {
    <#
    .SYNOPSIS
    Counts the number of SMTP site links in Active Directory.

    .DESCRIPTION
    This test retrieves the Active Directory site link configuration and counts SMTP site links.
    SMTP site links are identified by having a non-zero cost and lacking a replication frequency
    value.

    .EXAMPLE
    Test-MtAdSmtpSiteLinksCount

    Returns $true if SMTP site link data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSmtpSiteLinksCount
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

    $config = $adState.Configuration
    $siteLinks = if ($null -ne $config -and $null -ne $config.SiteLinks) { @($config.SiteLinks) } else { @() }
    $smtpSiteLinks = $siteLinks | Where-Object { $_.cost -and -not $_.ReplicationFrequencyInMinutes }
    $smtpSiteLinksCount = ($smtpSiteLinks | Measure-Object).Count

    # Test passes if we successfully retrieved configuration data
    $testResult = $null -ne $config -and $null -ne $config.SiteLinks

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| SMTP Site Links Count | $smtpSiteLinksCount |`n"

        $testResultMarkdown = "Active Directory SMTP site links have been analyzed. Found $smtpSiteLinksCount SMTP site link(s).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory site link information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


