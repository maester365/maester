function Test-MtAdDnsDuplicateZoneCount {
    <#
    .SYNOPSIS
    Counts duplicate or conflict DNS zones.

    .DESCRIPTION
    This test identifies DNS zones that appear to be duplicates or conflict objects.
    Duplicate zones (often indicated by CNF: or InProgress- prefixes in their names)
    may result from replication conflicts or incomplete zone creation operations.
    These should be investigated and resolved to ensure DNS consistency.

    .EXAMPLE
    Test-MtAdDnsDuplicateZoneCount

    Returns $true if DNS zone data is accessible, $false otherwise.
    The test result includes the count of duplicate/conflict zones.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsDuplicateZoneCount
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

    # Find duplicate/conflict zones
    $duplicateZones = $dnsZones | Where-Object {
        $_.ZoneName -like "* CNF:*" -or
        $_.ZoneName -like "..InProgress-*"
    }

    $duplicateCount = ($duplicateZones | Measure-Object).Count
    $totalZoneCount = ($dnsZones | Measure-Object).Count

    # Test passes if we successfully retrieved DNS data
    $testResult = $totalZoneCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total DNS Zones | $totalZoneCount |`n"
        $result += "| Duplicate/Conflict Zones | $duplicateCount |`n"

        if ($duplicateCount -gt 0) {
            $result += "`n### Duplicate/Conflict Zones`n`n"
            $result += "| Zone Name | Zone Type |`n"
            $result += "| --- | --- |`n"
            foreach ($zone in $duplicateZones) {
                $result += "| $($zone.ZoneName) | $($zone.ZoneType) |`n"
            }

            $result += "`n> **Note**: Duplicate zones (CNF:) indicate replication conflicts. These should be investigated and resolved on each domain controller.`n"
        }

        $testResultMarkdown = "Active Directory DNS zones have been analyzed. $duplicateCount duplicate or conflict zones were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNS zone data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


