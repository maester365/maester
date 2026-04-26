function Test-MtAdDnsZoneCount {
    <#
    .SYNOPSIS
    Counts the number of DNS zones with records in Active Directory.

    .DESCRIPTION
    This test retrieves the count of DNS zones that contain resource records.
    DNS zones are used to organize and manage DNS records for the domain.
    Understanding the number of zones helps assess DNS infrastructure complexity.

    .EXAMPLE
    Test-MtAdDnsZoneCount

    Returns $true if DNS zone data is accessible, $false otherwise.
    The test result includes the count of zones with records.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsZoneCount
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

    $dnsZones = $adState.DNSZones
    $dnsRecords = $adState.DNSRecords

    # If DNS data is not available, skip the test
    if ($null -eq $dnsZones -or $dnsZones.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory -SkippedBecauseReason "DNS data is not available. Ensure the DnsServer module is installed and you have appropriate permissions."
        return $null
    }

    # Count zones with records
    $zonesWithRecords = $dnsRecords | Group-Object ZoneName
    $zonesWithRecordsCount = ($zonesWithRecords | Measure-Object).Count
    $totalZoneCount = ($dnsZones | Measure-Object).Count

    # Test passes if we successfully retrieved DNS data
    $testResult = $totalZoneCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total DNS Zones | $totalZoneCount |`n"
        $result += "| Zones with Records | $zonesWithRecordsCount |`n"
        $result += "| Empty Zones | $($totalZoneCount - $zonesWithRecordsCount) |`n"

        $testResultMarkdown = "Active Directory DNS zones have been analyzed. $zonesWithRecordsCount out of $totalZoneCount zones contain resource records.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory DNS zone data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


