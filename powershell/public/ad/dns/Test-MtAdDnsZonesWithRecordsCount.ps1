function Test-MtAdDnsZonesWithRecordsCount {
    <#
    .SYNOPSIS
    Counts DNS zones that contain non-default records.

    .DESCRIPTION
    This test identifies DNS zones that contain records beyond the default SOA and NS records.
    These zones are actively used for DNS resolution and may contain A, AAAA, CNAME, MX,
    SRV, and other record types essential for domain services.

    .EXAMPLE
    Test-MtAdDnsZonesWithRecordsCount

    Returns $true if DNS zone data is accessible, $false otherwise.
    The test result includes the count of zones with non-default records.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsZonesWithRecordsCount
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

    # Define default zones to exclude
    $defaultZones = @("RootDNSServers", "..TrustAnchors", "_msdcs.*")
    $excludedRecordTypes = @("SOA", "NS")

    # Find zones with non-default records
    $zonesWithRecords = @()
    foreach ($zone in $dnsZones) {
        # Skip default zones
        $isDefaultZone = $false
        foreach ($defaultZone in $defaultZones) {
            if ($zone.ZoneName -like $defaultZone -or $zone.ZoneName -eq $defaultZone.TrimStart('.')) {
                $isDefaultZone = $true
                break
            }
        }

        if (-not $isDefaultZone -and $zone.ZoneName -notlike "*.in-addr.arpa") {
            $zoneRecords = $dnsRecords | Where-Object { $_.ZoneName -eq $zone.ZoneName }
            $nonDefaultRecords = $zoneRecords | Where-Object { $_.RecordType -notin $excludedRecordTypes }

            if (($nonDefaultRecords | Measure-Object).Count -gt 0) {
                $zonesWithRecords += $zone
            }
        }
    }

    $zonesWithRecordsCount = ($zonesWithRecords | Measure-Object).Count
    $totalZoneCount = ($dnsZones | Measure-Object).Count

    # Test passes if we successfully retrieved DNS data
    $testResult = $totalZoneCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total DNS Zones | $totalZoneCount |`n"
        $result += "| Zones with Non-Default Records | $zonesWithRecordsCount |`n"
        $result += "| Zones with Only Default Records | $($totalZoneCount - $zonesWithRecordsCount) |`n"

        if ($zonesWithRecordsCount -gt 0) {
            $result += "`n### Zones with Non-Default Records`n`n"
            $result += "| Zone Name | Zone Type |`n"
            $result += "| --- | --- |`n"
            foreach ($zone in $zonesWithRecords | Select-Object -First 10) {
                $result += "| $($zone.ZoneName) | $($zone.ZoneType) |`n"
            }
            if ($zonesWithRecordsCount -gt 10) {
                $result += "| ... and $($zonesWithRecordsCount - 10) more | |`n"
            }
        }

        $testResultMarkdown = "Active Directory DNS zones have been analyzed. $zonesWithRecordsCount out of $totalZoneCount zones contain non-default records.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNS zone data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


