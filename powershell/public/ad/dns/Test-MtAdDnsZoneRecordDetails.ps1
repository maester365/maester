function Test-MtAdDnsZoneRecordDetails {
    <#
    .SYNOPSIS
    Provides detailed record count information for each DNS zone.

    .DESCRIPTION
    This test retrieves detailed information about DNS record distribution across zones.
    It provides a breakdown of record counts per zone, helping identify zones with
    high record counts that may require optimization or zones that are underutilized.

    .EXAMPLE
    Test-MtAdDnsZoneRecordDetails

    Returns $true if DNS zone data is accessible, $false otherwise.
    The test result includes a detailed breakdown of records per zone.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsZoneRecordDetails
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

    # Calculate record counts per zone
    $zoneRecordCounts = @()
    foreach ($zone in $dnsZones) {
        $zoneRecords = $dnsRecords | Where-Object { $_.ZoneName -eq $zone.ZoneName }
        $recordCount = ($zoneRecords | Measure-Object).Count

        # Count by record type
        $recordTypes = $zoneRecords | Group-Object RecordType | Sort-Object Count -Descending

        $zoneRecordCounts += [PSCustomObject]@{
            ZoneName = $zone.ZoneName
            ZoneType = $zone.ZoneType
            RecordCount = $recordCount
            RecordTypes = $recordTypes
        }
    }

    $totalZones = ($dnsZones | Measure-Object).Count
    $totalRecords = ($dnsRecords | Measure-Object).Count
    $averageRecordsPerZone = if ($totalZones -gt 0) { [Math]::Round($totalRecords / $totalZones, 2) } else { 0 }

    # Test passes if we successfully retrieved DNS data
    $testResult = $totalZones -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total DNS Zones | $totalZones |`n"
        $result += "| Total DNS Records | $totalRecords |`n"
        $result += "| Average Records per Zone | $averageRecordsPerZone |`n"

        if ($zoneRecordCounts.Count -gt 0) {
            $result += "`n### Record Count by Zone (Top 15)`n`n"
            $result += "| Zone Name | Zone Type | Record Count | Top Record Types |`n"
            $result += "| --- | --- | --- | --- |`n"

            $sortedZones = $zoneRecordCounts | Sort-Object RecordCount -Descending | Select-Object -First 15
            foreach ($zoneInfo in $sortedZones) {
                $topTypes = ($zoneInfo.RecordTypes | Select-Object -First 3 | ForEach-Object { "$($_.Name):$($_.Count)" }) -join ", "
                $result += "| $($zoneInfo.ZoneName) | $($zoneInfo.ZoneType) | $($zoneInfo.RecordCount) | $topTypes |`n"
            }
        }

        $testResultMarkdown = "Active Directory DNS zone record details have been analyzed. $totalZones zones contain $totalRecords records.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNS zone data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


