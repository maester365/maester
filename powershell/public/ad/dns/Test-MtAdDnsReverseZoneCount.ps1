function Test-MtAdDnsReverseZoneCount {
    <#
    .SYNOPSIS
    Counts reverse lookup DNS zones.

    .DESCRIPTION
    This test retrieves the count of reverse lookup zones configured in Active Directory.
    Reverse lookup zones enable DNS resolution from IP addresses to hostnames (PTR records).
    These zones are essential for network troubleshooting, security auditing, and
    various applications that require IP-to-name resolution.

    .EXAMPLE
    Test-MtAdDnsReverseZoneCount

    Returns $true if DNS zone data is accessible, $false otherwise.
    The test result includes the count of reverse lookup zones.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsReverseZoneCount
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

    # If DNS data is not available, skip the test
    if ($null -eq $dnsZones -or $dnsZones.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory -SkippedBecauseReason "DNS data is not available. Ensure the DnsServer module is installed and you have appropriate permissions."
        return $null
    }

    # Find reverse lookup zones
    $reverseZones = $dnsZones | Where-Object {
        $_.ZoneName -like "*.in-addr.arpa" -or
        $_.ZoneName -like "*.ip6.arpa"
    }

    $ipv4ReverseZones = $dnsZones | Where-Object { $_.ZoneName -like "*.in-addr.arpa" }
    $ipv6ReverseZones = $dnsZones | Where-Object { $_.ZoneName -like "*.ip6.arpa" }

    $reverseZoneCount = ($reverseZones | Measure-Object).Count
    $totalZoneCount = ($dnsZones | Measure-Object).Count

    # Test passes if we successfully retrieved DNS data
    $testResult = $totalZoneCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total DNS Zones | $totalZoneCount |`n"
        $result += "| Reverse Lookup Zones | $reverseZoneCount |`n"
        $result += "| IPv4 Reverse Zones (.in-addr.arpa) | $(($ipv4ReverseZones | Measure-Object).Count) |`n"
        $result += "| IPv6 Reverse Zones (.ip6.arpa) | $(($ipv6ReverseZones | Measure-Object).Count) |`n"
        $result += "| Forward Lookup Zones | $($totalZoneCount - $reverseZoneCount) |`n"

        $testResultMarkdown = "Active Directory DNS zones have been analyzed. $reverseZoneCount reverse lookup zones were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNS zone data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


