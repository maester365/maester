function Test-MtAdDnsReverseZoneNetworkDetails {
    <#
    .SYNOPSIS
    Provides detailed information about networks with reverse lookup zones.

    .DESCRIPTION
    This test retrieves detailed information about networks that have reverse lookup zones
    configured in Active Directory. It provides a list of network addresses and their
    corresponding reverse zones, helping assess DNS coverage for reverse resolution.

    .EXAMPLE
    Test-MtAdDnsReverseZoneNetworkDetails

    Returns $true if DNS zone data is accessible, $false otherwise.
    The test result includes detailed information about networks with reverse zones.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsReverseZoneNetworkDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
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
        # e.g., "1.168.192.in-addr.arpa" -> "192.168.1.0/24"
        $zoneParts = $zone.ZoneName -replace '\.in-addr\.arpa$', '' -split '\.'
        [array]::Reverse($zoneParts)
        $networkAddress = $zoneParts -join '.'

        # Determine subnet mask based on number of octets
        $octetCount = $zoneParts.Count
        $cidr = $octetCount * 8
        $networkWithCidr = "$networkAddress.0/$cidr"

        $networks += [PSCustomObject]@{
            NetworkAddress  = $networkAddress
            CIDR            = $cidr
            NetworkWithCidr = $networkWithCidr
            ZoneName        = $zone.ZoneName
            ZoneType        = $zone.ZoneType
        }
    }

    $networkCount = ($networks | Measure-Object).Count

    # Test passes if we successfully retrieved DNS data
    $testResult = $networkCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Networks with Reverse Zones | $networkCount |`n"

        if ($networkCount -gt 0) {
            $result += "`n### Network Details`n`n"
            $result += "| Network | CIDR | Reverse Zone | Zone Type |`n"
            $result += "| --- | --- | --- | --- |`n"

            foreach ($network in $networks | Sort-Object NetworkAddress) {
                $result += "| $($network.NetworkAddress).0 | /$($network.CIDR) | $($network.ZoneName) | $($network.ZoneType) |`n"
            }
        }

        $testResultMarkdown = "Active Directory DNS reverse zone network details have been analyzed. $networkCount networks have reverse lookup zones.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNS zone data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


