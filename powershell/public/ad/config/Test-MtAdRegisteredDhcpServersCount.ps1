function Test-MtAdRegisteredDhcpServersCount {
    <#
    .SYNOPSIS
    Counts the number of DHCP servers registered in Active Directory.

    .DESCRIPTION
    This test retrieves the Active Directory configuration data for registered DHCP
    servers and reports the number of objects present.

    .EXAMPLE
    Test-MtAdRegisteredDhcpServersCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdRegisteredDhcpServersCount
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

    $config = $adState.Configuration
    $dhcpServers = $config.DhcpServers
    $dhcpServersCount = @($dhcpServers).Count
    $hasData = $null -ne $config.DhcpServers

    # Test passes when configuration data is available
    $testResult = $hasData -and ($dhcpServersCount -ge 0)

    # Generate markdown results
    if ($hasData) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Registered DHCP Servers Count | $dhcpServersCount |`n"
        $testResultMarkdown = "Active Directory registered DHCP servers have been counted. $dhcpServersCount DHCP server(s) were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory configuration data for DhcpServers. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


