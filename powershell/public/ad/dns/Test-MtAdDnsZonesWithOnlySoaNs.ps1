function Test-MtAdDnsZonesWithOnlySoaNs {
    <#
    .SYNOPSIS
    Counts DNS zones that contain only SOA and NS records.

    .DESCRIPTION
    This test identifies DNS zones that only contain Start of Authority (SOA) and
    Name Server (NS) records. These are default records created when a zone is established.
    Zones with only these records may indicate unused or placeholder zones.

    .EXAMPLE
    Test-MtAdDnsZonesWithOnlySoaNs

    Returns $true if DNS zone data is accessible, $false otherwise.
    The test result includes the count of zones with only SOA/NS records.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsZonesWithOnlySoaNs
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

    # Find zones with only SOA and NS records
    $zonesWithOnlySoaNs = @()
    foreach ($zone in $dnsZones) {
        $zoneRecords = $dnsRecords | Where-Object { $_.ZoneName -eq $zone.ZoneName }
        $nonSoaNsRecords = $zoneRecords | Where-Object { $_.RecordType -notin @('SOA', 'NS') }

        if (($zoneRecords | Measure-Object).Count -gt 0 -and ($nonSoaNsRecords | Measure-Object).Count -eq 0) {
            $zonesWithOnlySoaNs += $zone
        }
    }

    $zonesWithOnlySoaNsCount = ($zonesWithOnlySoaNs | Measure-Object).Count
    $totalZoneCount = ($dnsZones | Measure-Object).Count

    # Test passes if we successfully retrieved DNS data
    $testResult = $totalZoneCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalZoneCount -gt 0) {
            [Math]::Round(($zonesWithOnlySoaNsCount / $totalZoneCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total DNS Zones | $totalZoneCount |`n"
        $result += "| Zones with Only SOA/NS | $zonesWithOnlySoaNsCount |`n"
        $result += "| Percentage | $percentage% |`n"

        if ($zonesWithOnlySoaNsCount -gt 0) {
            $result += "`n### Zones with Only SOA/NS Records`n`n"
            $result += "| Zone Name | Zone Type |`n"
            $result += "| --- | --- |`n"
            foreach ($zone in $zonesWithOnlySoaNs | Select-Object -First 10) {
                $result += "| $($zone.ZoneName) | $($zone.ZoneType) |`n"
            }
        }

        $testResultMarkdown = "Active Directory DNS zones have been analyzed. $zonesWithOnlySoaNsCount out of $totalZoneCount zones contain only SOA and NS records.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory DNS zone data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


