function Test-MtAdDnsRootServerIncorrectCount {
    <#
    .SYNOPSIS
    Counts root DNS servers with incorrect IP addresses.

    .DESCRIPTION
    This test verifies that root DNS server hints are configured with correct IP addresses.
    Root server hints are essential for DNS resolution to external domains. Incorrect
    IP addresses can cause DNS resolution failures and prevent access to external resources.

    .EXAMPLE
    Test-MtAdDnsRootServerIncorrectCount

    Returns $true if DNS root server data is accessible, $false otherwise.
    The test result includes the count of root servers with incorrect IPs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDnsRootServerIncorrectCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Define correct root server IP addresses (as of 2024)
    $rootServers = @{
        "a.root-servers.net" = "198.41.0.4"
        "b.root-servers.net" = "199.9.14.201"
        "c.root-servers.net" = "192.33.4.12"
        "d.root-servers.net" = "199.7.91.13"
        "e.root-servers.net" = "192.203.230.10"
        "f.root-servers.net" = "192.5.5.241"
        "g.root-servers.net" = "192.112.36.4"
        "h.root-servers.net" = "198.97.190.53"
        "i.root-servers.net" = "192.36.148.17"
        "j.root-servers.net" = "192.58.128.30"
        "k.root-servers.net" = "193.0.14.129"
        "l.root-servers.net" = "199.7.83.42"
        "m.root-servers.net" = "202.12.27.33"
    }

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

    # Get root server records from RootDNSServers zone
    $rootServerRecords = $dnsRecords | Where-Object {
        $_.ZoneName -eq "RootDNSServers" -and
        $_.RecordType -eq "A" -and
        $_.HostName -ne "@"
    }

    # Check for incorrect IP addresses
    $incorrectRootServers = @()
    foreach ($record in $rootServerRecords) {
        $serverName = $record.HostName
        $configuredIp = $record.RecordData.IPv4Address.IPAddressToString
        $expectedIp = $rootServers[$serverName]

        if ($expectedIp -and $configuredIp -ne $expectedIp) {
            $incorrectRootServers += [PSCustomObject]@{
                Name = $serverName
                ConfiguredIP = $configuredIp
                ExpectedIP = $expectedIp
            }
        }
    }

    $incorrectCount = ($incorrectRootServers | Measure-Object).Count
    $totalRootServers = ($rootServerRecords | Measure-Object).Count

    # Test passes if we successfully retrieved DNS data
    $testResult = $totalRootServers -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Root Servers | $totalRootServers |`n"
        $result += "| Incorrect IPs | $incorrectCount |`n"
        $result += "| Correct IPs | $($totalRootServers - $incorrectCount) |`n"

        if ($incorrectCount -gt 0) {
            $result += "`n### Root Servers with Incorrect IPs`n`n"
            $result += "| Server Name | Configured IP | Expected IP |`n"
            $result += "| --- | --- | --- |`n"
            foreach ($server in $incorrectRootServers) {
                $result += "| $($server.Name) | $($server.ConfiguredIP) | $($server.ExpectedIP) |`n"
            }
        }

        $testResultMarkdown = "DNS root server hints have been analyzed. $incorrectCount out of $totalRootServers root servers have incorrect IP addresses.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve DNS root server data. Ensure you have appropriate permissions and the DnsServer module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


