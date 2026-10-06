function Test-MtAdDnsAdSrvRecordDetails {
    <#
    .SYNOPSIS
    Provides detailed information about Active Directory Domain Services SRV records.

    .DESCRIPTION
    This test retrieves detailed information about SRV records used by Active Directory
    Domain Services. It provides specific details about each SRV record including the
    service, protocol, target host, port, priority, and weight.

    .EXAMPLE
    Test-MtAdDnsAdSrvRecordDetails

    Returns $true if DNS SRV record data is accessible, $false otherwise.
    The test result includes detailed information about AD DS SRV records.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsAdSrvRecordDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [MaesterTest(
        Id = 'AD-DNS-12',
        Title = 'AD DS SRV record details should be retrievable',
        Severity = 'Info',
        Category = 'Active Directory - DNS Infrastructure',
        Tag = 'AD.DNS',
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdDnsAdSrvRecordDetails"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('DNS')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $dnsRecords = $adState.DNSRecords

    # If DNS data is not available, skip the test
    if ($null -eq $dnsRecords -or $dnsRecords.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectoryDNS -Result "Active Directory DNS data could not be retrieved. Ensure the target domain controller is reachable and the management session can access the MicrosoftDNS WMI namespace."
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

    # Test passes if we successfully retrieved DNS data
    $testResult = $adSrvCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| AD DS SRV Records | $adSrvCount |" + "`n"

        if ($adSrvCount -gt 0) {
            $result += "`n### AD DS SRV Record Details" + "`n" + "`n"
            $result += "| Record Name | Zone | Target Host | Port | Priority | Weight |" + "`n"
            $result += "| --- | --- | --- | --- | --- | --- |" + "`n"

            foreach ($srv in $adSrvRecords | Sort-Object ZoneName, HostName) {
                $recordName = $srv.HostName
                $zone = $srv.ZoneName
                $targetHost = $srv.RecordData.DomainName
                $port = $srv.RecordData.Port
                $priority = $srv.RecordData.Priority
                $weight = $srv.RecordData.Weight

                $result += "| $recordName | $zone | $targetHost | $port | $priority | $weight |" + "`n"
            }
        }

        $testResultMarkdown = "Active Directory DNS SRV record details have been analyzed. $adSrvCount AD DS SRV records were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNS SRV record data. Ensure the target domain controller is reachable and the management session can access the MicrosoftDNS WMI namespace."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
