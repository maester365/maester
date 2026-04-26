function Test-MtAdDnsReverseZoneNetworkCount {
    <#
    .SYNOPSIS
    Counts distinct networks with reverse lookup zones.

    .DESCRIPTION
    This test counts the number of unique networks that have reverse lookup zones configured.
    Reverse lookup zones are organized by network address in the in-addr.arpa domain.
    This test helps assess network coverage for reverse DNS resolution.

    .EXAMPLE
    Test-MtAdDnsReverseZoneNetworkCount

    Returns $true if DNS zone data is accessible, $false otherwise.
    The test result includes the count of networks with reverse zones.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsReverseZoneNetworkCount
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

    # Find IPv4 reverse lookup zones and extract network addresses
    $reverseZones = $dnsZones | Where-Object { $_.ZoneName -like "*.in-addr.arpa" }

    $networks = @()
    foreach ($zone in $reverseZones) {
        # Parse the reverse zone name to get the network address
        # e.g., "1.168.192.in-addr.arpa" -> "192.168.1"
        $zoneParts = $zone.ZoneName -replace '\.in-addr\.arpa$', '' -split '\.'
        [array]::Reverse($zoneParts)
        $networkAddress = $zoneParts -join '.'

        $networks += [PSCustomObject]@{
            NetworkAddress = $networkAddress
            ZoneName = $zone.ZoneName
        }
    }

    $networkCount = ($networks | Select-Object -Property NetworkAddress -Unique | Measure-Object).Count
    $reverseZoneCount = ($reverseZones | Measure-Object).Count

    # Test passes if we successfully retrieved DNS data
    $testResult = $reverseZoneCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Reverse Lookup Zones | $reverseZoneCount |`n"
        $result += "| Distinct Networks | $networkCount |`n"

        $testResultMarkdown = "Active Directory DNS reverse zones have been analyzed. $networkCount distinct networks have reverse lookup zones.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNS zone data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


