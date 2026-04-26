function Test-MtAdDnsAdSrvRecordCount {
    <#
    .SYNOPSIS
    Counts Active Directory Domain Services SRV records.

    .DESCRIPTION
    This test retrieves the count of SRV records used by Active Directory Domain Services.
    These records are essential for domain controller location and include services like
    LDAP (_ldap), Global Catalog (_gc), Kerberos (_kerberos), and kpasswd (_kpasswd).

    .EXAMPLE
    Test-MtAdDnsAdSrvRecordCount

    Returns $true if DNS SRV record data is accessible, $false otherwise.
    The test result includes the count of AD DS SRV records.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsAdSrvRecordCount
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

    $dnsRecords = $adState.DNSRecords

    # If DNS data is not available, skip the test
    if ($null -eq $dnsRecords -or $dnsRecords.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory -SkippedBecauseReason "DNS data is not available. Ensure the DnsServer module is installed and you have appropriate permissions."
        return $null
    }

    # Define AD DS SRV record patterns
    $adSrvPatterns = @("_ldap.*", "_gc.*", "_kerberos.*", "_kpasswd.*")

    # Find AD DS SRV records
    $adSrvRecords = @()
    foreach ($pattern in $adSrvPatterns) {
        $matchingRecords = $dnsRecords | Where-Object {
            $_.RecordType -eq "SRV" -and
            $_.HostName -like $pattern
        }
        $adSrvRecords += $matchingRecords
    }

    $adSrvCount = ($adSrvRecords | Measure-Object).Count
    $totalSrvRecords = ($dnsRecords | Where-Object { $_.RecordType -eq "SRV" } | Measure-Object).Count

    # Test passes if we successfully retrieved DNS data
    $testResult = $totalSrvRecords -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total SRV Records | $totalSrvRecords |`n"
        $result += "| AD DS SRV Records | $adSrvCount |`n"
        $result += "| Non-AD SRV Records | $($totalSrvRecords - $adSrvCount) |`n"

        # Count by service type
        $srvByService = $adSrvRecords | ForEach-Object {
            if ($_.HostName -match "^(_[^.]+)") { $matches[1] } else { "Other" }
        } | Group-Object | Sort-Object Count -Descending

        if ($srvByService.Count -gt 0) {
            $result += "`n### AD DS SRV Records by Service`n`n"
            $result += "| Service | Count |`n"
            $result += "| --- | --- |`n"
            foreach ($service in $srvByService) {
                $result += "| $($service.Name) | $($service.Count) |`n"
            }
        }

        $testResultMarkdown = "Active Directory DNS SRV records have been analyzed. $adSrvCount AD DS SRV records were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNS SRV record data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


