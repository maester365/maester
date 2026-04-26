function Test-MtAdDnsZoneDelegationDetails {
    <#
    .SYNOPSIS
    Provides detailed information about DNS zone delegations.

    .DESCRIPTION
    This test retrieves detailed information about DNS zone delegations configured
    in Active Directory. It provides specific details about each delegated subdomain,
    including the target name servers and parent zones.

    .EXAMPLE
    Test-MtAdDnsZoneDelegationDetails

    Returns $true if DNS delegation data is accessible, $false otherwise.
    The test result includes detailed information about zone delegations.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsZoneDelegationDetails
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

    # Group delegations by zone
    $delegationsByZone = $delegationRecords | Group-Object ZoneName

    # Test passes if we successfully retrieved DNS data
    $testResult = $delegationCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Zone Delegations | $delegationCount |`n"
        $result += "| Zones with Delegations | $(($delegationsByZone | Measure-Object).Count) |`n"

        if ($delegationCount -gt 0) {
            $result += "`n### Zone Delegation Details`n`n"
            $result += "| Parent Zone | Delegated Subdomain | Target Name Server |`n"
            $result += "| --- | --- | --- |`n"

            foreach ($record in $delegationRecords | Sort-Object ZoneName, HostName) {
                $delegatedName = if ($record.HostName -eq "") { "@" } else { $record.HostName }
                $targetNs = $record.RecordData.NameServer
                $result += "| $($record.ZoneName) | $delegatedName | $targetNs |`n"
            }
        }

        $testResultMarkdown = "Active Directory DNS zone delegation details have been analyzed. $delegationCount zone delegations were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNS delegation data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}



