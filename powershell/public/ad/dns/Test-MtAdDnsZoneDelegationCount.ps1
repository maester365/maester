function Test-MtAdDnsZoneDelegationCount {
    <#
    .SYNOPSIS
    Counts the number of DNS zone delegations in Active Directory.

    .DESCRIPTION
    This test retrieves the count of DNS zone delegations configured in Active Directory.
    Zone delegations allow child zones to be managed by different DNS servers or
    administrative entities. Monitoring delegations helps ensure proper DNS hierarchy
    and identifies potential security boundaries.

    .EXAMPLE
    Test-MtAdDnsZoneDelegationCount

    Returns $true if DNS delegation data is accessible, $false otherwise.
    The test result includes the count of zone delegations.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsZoneDelegationCount
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

    # Find NS records that represent delegations (NS records where Name is not @)
    $delegationRecords = $dnsRecords | Where-Object {
        $_.RecordType -eq "NS" -and
        $_.HostName -ne "@"
    }

    $delegationCount = ($delegationRecords | Measure-Object).Count
    $totalNsRecords = ($dnsRecords | Where-Object { $_.RecordType -eq "NS" } | Measure-Object).Count

    # Test passes if we successfully retrieved DNS data
    $testResult = $totalNsRecords -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total NS Records | $totalNsRecords |`n"
        $result += "| Zone Delegations | $delegationCount |`n"
        $result += "| Standard NS Records | $($totalNsRecords - $delegationCount) |`n"

        $testResultMarkdown = "Active Directory DNS zone delegations have been analyzed. $delegationCount zone delegations were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNS delegation data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


