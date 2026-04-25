function Test-MtAdSubnetIpv6Count {
    <#
    .SYNOPSIS
    Counts the number of IPv6 subnets configured in Active Directory.

    .DESCRIPTION
    This test retrieves the count of IPv6 subnets configured in Active Directory.
    IPv6 subnets are used for client site assignment in IPv6-enabled networks.

    .EXAMPLE
    Test-MtAdSubnetIpv6Count

    Returns $true if subnet data is accessible.
    The test result includes the count of IPv6 subnets.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSubnetIpv6Count
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

    $subnets = $adState.Subnets
    $totalSubnets = ($subnets | Measure-Object).Count

    # Identify IPv6 subnets (contain colons or are IPv6 format)
    $ipv6Subnets = $subnets | Where-Object {
        $_.Name -match ':' -or $_.Name -match '^[0-9a-fA-F]{1,4}:'
    }
    $ipv6Count = ($ipv6Subnets | Measure-Object).Count
    $ipv4Count = $totalSubnets - $ipv6Count

    # Test passes if we successfully retrieved data
    $testResult = $totalSubnets -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Subnets | $totalSubnets |`n"
        $result += "| IPv4 Subnets | $ipv4Count |`n"
        $result += "| IPv6 Subnets | $ipv6Count |`n"

        if ($ipv6Count -gt 0) {
            $result += "`n### IPv6 Subnets`n`n"
            $result += "| Subnet | Site |`n"
            $result += "| --- | --- |`n"

            foreach ($subnet in ($ipv6Subnets | Sort-Object Name)) {
                $siteName = if ($subnet.SiteObject) {
                    ($subnet.SiteObject -split ',')[0] -replace '^CN=', ''
                } else { "Unassigned" }
                $result += "| $($subnet.Name) | $siteName |`n"
            }
        }

        $testResultMarkdown = "Active Directory IPv6 subnet analysis has been performed. $ipv6Count IPv6 subnet(s) were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory subnet information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
