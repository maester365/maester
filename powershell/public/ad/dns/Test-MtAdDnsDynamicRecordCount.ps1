function Test-MtAdDnsDynamicRecordCount {
    <#
    .SYNOPSIS
    Counts the number of dynamic DNS records in Active Directory.

    .DESCRIPTION
    This test retrieves the count of dynamic DNS records in Active Directory-integrated zones.
    Dynamic DNS allows clients to register and update their own DNS records automatically.
    Monitoring dynamic records helps assess the security posture of DNS registration.

    .EXAMPLE
    Test-MtAdDnsDynamicRecordCount

    Returns $true if DNS record data is accessible, $false otherwise.
    The test result includes the count of dynamic vs static records.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsDynamicRecordCount
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

    # Count dynamic vs static records
    # Dynamic records have a timestamp (not static)
    $dynamicRecords = $dnsRecords | Where-Object { $null -ne $_.Timestamp }
    $staticRecords = $dnsRecords | Where-Object { $null -eq $_.Timestamp }

    $dynamicCount = ($dynamicRecords | Measure-Object).Count
    $staticCount = ($staticRecords | Measure-Object).Count
    $totalCount = ($dnsRecords | Measure-Object).Count

    # Test passes if we successfully retrieved DNS data
    $testResult = $totalCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $dynamicPercentage = if ($totalCount -gt 0) {
            [Math]::Round(($dynamicCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total DNS Records | $totalCount |`n"
        $result += "| Dynamic Records | $dynamicCount |`n"
        $result += "| Static Records | $staticCount |`n"
        $result += "| Dynamic Percentage | $dynamicPercentage% |`n"

        $testResultMarkdown = "Active Directory DNS records have been analyzed. $dynamicCount out of $totalCount records ($dynamicPercentage%) are dynamic.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNS record data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}




