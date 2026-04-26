function Test-MtAdDnsNonStandardZoneCount {
    <#
    .SYNOPSIS
    Counts DNS zones with non-standard names.

    .DESCRIPTION
    This test identifies DNS zones that do not conform to RFC standards for domain names.
    Non-standard zone names may cause compatibility issues with DNS clients and
    applications. This test checks compliance with RFCs 952, 1035, and 1123.

    .EXAMPLE
    Test-MtAdDnsNonStandardZoneCount

    Returns $true if DNS zone data is accessible, $false otherwise.
    The test result includes the count of non-standard zone names.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsNonStandardZoneCount
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

    # Find non-standard zones (excluding special zones like TrustAnchors and _msdcs)
    $nonStandardZones = $dnsZones | Where-Object {
        $zoneName = $_.ZoneName
        $isStandard = $zoneName -match '^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'

        -not $isStandard -and
        $zoneName -ne "..TrustAnchors" -and
        $zoneName -notlike "_msdcs.*" -and
        $zoneName -notlike "*.in-addr.arpa" -and
        $zoneName -notlike "*.ip6.arpa"
    }

    $nonStandardCount = ($nonStandardZones | Measure-Object).Count
    $totalZoneCount = ($dnsZones | Measure-Object).Count

    # Test passes if we successfully retrieved DNS data
    $testResult = $totalZoneCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total DNS Zones | $totalZoneCount |`n"
        $result += "| Non-Standard Zones | $nonStandardCount |`n"
        $result += "| Standard Zones | $($totalZoneCount - $nonStandardCount) |`n"

        if ($nonStandardCount -gt 0) {
            $result += "`n### Non-Standard Zone Names`n`n"
            $result += "| Zone Name | Zone Type |`n"
            $result += "| --- | --- |`n"
            foreach ($zone in $nonStandardZones) {
                $result += "| $($zone.ZoneName) | $($zone.ZoneType) |`n"
            }

            $result += "`n> **Note**: Non-standard zone names do not comply with RFCs 952, 1035, and 1123 for internet domain names.`n"
        }

        $testResultMarkdown = "Active Directory DNS zones have been analyzed. $nonStandardCount zones have non-standard names.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNS zone data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


