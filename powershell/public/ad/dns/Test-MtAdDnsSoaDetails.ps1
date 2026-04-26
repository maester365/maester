function Test-MtAdDnsSoaDetails {
    <#
    .SYNOPSIS
    Provides SOA (Start of Authority) record details for each DNS zone.

    .DESCRIPTION
    This test retrieves SOA record information for each DNS zone in Active Directory.
    SOA records contain critical zone management information including the primary
    DNS server, responsible administrator email, serial number, and refresh/retry/expire timers.

    .EXAMPLE
    Test-MtAdDnsSoaDetails

    Returns $true if DNS SOA data is accessible, $false otherwise.
    The test result includes SOA record details for each zone.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsSoaDetails
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
    $dnsRecords = $adState.DNSRecords

    # If DNS data is not available, skip the test
    if ($null -eq $dnsZones -or $dnsZones.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory -SkippedBecauseReason "DNS data is not available. Ensure the DnsServer module is installed and you have appropriate permissions."
        return $null
    }

    # Get SOA records for each zone
    $soaRecords = $dnsRecords | Where-Object { $_.RecordType -eq "SOA" }

    $soaCount = ($soaRecords | Measure-Object).Count
    $totalZones = ($dnsZones | Measure-Object).Count

    # Test passes if we successfully retrieved DNS data
    $testResult = $totalZones -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Zones | $totalZones |`n"
        $result += "| Zones with SOA Records | $soaCount |`n"

        if ($soaCount -gt 0) {
            $result += "`n### SOA Record Details`n`n"
            $result += "| Zone Name | Primary Server | Responsible Party | Serial | Refresh | Retry | Expire | TTL |`n"
            $result += "| --- | --- | --- | --- | --- | --- | --- | --- |`n"

            foreach ($soa in $soaRecords | Where-Object { $_.ZoneName -notlike "*.in-addr.arpa" } | Sort-Object ZoneName) {
                $primaryServer = $soa.RecordData.PrimaryServer
                $responsibleParty = $soa.RecordData.ResponsibleParty
                $serial = $soa.RecordData.SerialNumber
                $refresh = $soa.RecordData.RefreshInterval
                $retry = $soa.RecordData.RetryInterval
                $expire = $soa.RecordData.ExpireLimit
                $ttl = $soa.RecordData.MinimumTimeToLive

                $result += "| $($soa.ZoneName) | $primaryServer | $responsibleParty | $serial | $refresh | $retry | $expire | $ttl |`n"
            }
        }

        $testResultMarkdown = "Active Directory DNS SOA records have been analyzed. $soaCount zones have SOA records configured.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNS SOA data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


