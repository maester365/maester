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
    [MaesterTest(
        Id = 'AD-DNS-01',
        Title = 'DNS zone count should be retrievable',
        Severity = 'Info',
        Category = 'Active Directory - DNS Infrastructure',
        Tag = 'AD.DNS',
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdDnsZoneCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('DNS')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $dnsZones = $adState.DNSZones
    $dnsRecords = $adState.DNSRecords

    # If DNS data is not available, skip the test
    if ($null -eq $dnsZones -or $dnsZones.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectoryDNS -Result "Active Directory DNS data could not be retrieved. Ensure the target domain controller is reachable and the management session can access the MicrosoftDNS WMI namespace."
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
        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Total DNS Zones | $totalZoneCount |" + "`n"
        $result += "| Zones with Records | $zonesWithRecordsCount |" + "`n"
        $result += "| Empty Zones | $($totalZoneCount - $zonesWithRecordsCount) |" + "`n"

        $testResultMarkdown = "Active Directory DNS zones have been analyzed. $zonesWithRecordsCount out of $totalZoneCount zones contain resource records.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory DNS zone data. Ensure the target domain controller is reachable and the management session can access the MicrosoftDNS WMI namespace."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
