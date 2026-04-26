function Test-MtAdDnsDnssecRecordCount {
    <#
    .SYNOPSIS
    Counts DNSSEC (DNS Security Extensions) trust anchor records.

    .DESCRIPTION
    This test retrieves the count of DNSSEC trust anchor records configured in Active Directory.
    DNSSEC provides authentication of DNS data through digital signatures. Trust anchors
    are the starting points for DNSSEC validation chains.

    .EXAMPLE
    Test-MtAdDnsDnssecRecordCount

    Returns $true if DNSSEC data is accessible, $false otherwise.
    The test result includes the count of DNSSEC trust anchors.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsDnssecRecordCount
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

    # Find DNSSEC trust anchor records (typically in TrustAnchors zone)
    $dnssecRecords = $dnsRecords | Where-Object {
        $_.ZoneName -like "*TrustAnchors*" -and
        $_.HostName -ne "@"
    }

    $dnssecCount = ($dnssecRecords | Measure-Object).Count

    # Test passes if we successfully retrieved DNS data
    $testResult = $dnssecCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| DNSSEC Trust Anchors | $dnssecCount |`n"

        if ($dnssecCount -gt 0) {
            $result += "`n### DNSSEC Trust Anchor Details`n`n"
            $result += "| Record Name | Zone | Record Type |`n"
            $result += "| --- | --- | --- |`n"

            foreach ($record in $dnssecRecords | Sort-Object ZoneName, HostName) {
                $result += "| $($record.HostName) | $($record.ZoneName) | $($record.RecordType) |`n"
            }
        }

        $testResultMarkdown = "Active Directory DNSSEC configuration has been analyzed. $dnssecCount DNSSEC trust anchor records were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNSSEC data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


