function Test-MtAdSubnetIpv6CatchAllCount {
    <#
    .SYNOPSIS
    Counts the number of IPv6 catch-all subnets in Active Directory.

    .DESCRIPTION
    This test identifies IPv6 subnets that are configured with overly broad ranges.
    IPv6 catch-all subnets like /32 or /48 may cause clients to authenticate
    to distant domain controllers.

    .EXAMPLE
    Test-MtAdSubnetIpv6CatchAllCount

    Returns $true if subnet data is accessible.
    The test result includes the count of IPv6 catch-all subnets.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSubnetIpv6CatchAllCount
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

    # Identify IPv6 subnets with overly broad prefixes (/48 or larger)
    $ipv6CatchAllSubnets = $subnets | Where-Object {
        $subnetName = $_.Name
        if ($subnetName -match '^([0-9a-fA-F:]+)/([0-9]+)$') {
            $prefix = [int]$matches[2]
            # /48 or smaller (more encompassing) is considered catch-all for IPv6
            return $prefix -le 48
        }
        return $false
    }

    $ipv6CatchAllCount = ($ipv6CatchAllSubnets | Measure-Object).Count

    # Get all IPv6 subnets for context
    $ipv6Subnets = $subnets | Where-Object { $_.Name -match ':' }
    $totalIpv6Count = ($ipv6Subnets | Measure-Object).Count

    # Test passes if we successfully retrieved data
    $testResult = ($subnets | Measure-Object).Count -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total IPv6 Subnets | $totalIpv6Count |`n"
        $result += "| IPv6 Catch-All Subnets | $ipv6CatchAllCount |`n"

        if ($ipv6CatchAllCount -gt 0) {
            $result += "`n### IPv6 Catch-All Subnets`n`n"
            $result += "| Subnet | Site |`n"
            $result += "| --- | --- |`n"

            foreach ($subnet in ($ipv6CatchAllSubnets | Sort-Object Name)) {
                $siteName = if ($subnet.SiteObject) {
                    ($subnet.SiteObject -split ',')[0] -replace '^CN=', ''
                } else { "Unassigned" }
                $result += "| $($subnet.Name) | $siteName |`n"
            }

            $result += "`n> **Warning:** IPv6 catch-all subnets (prefix /48 or smaller) may cause clients to authenticate to distant domain controllers.`n"
        }

        $testResultMarkdown = "Active Directory IPv6 catch-all subnet analysis has been performed. $ipv6CatchAllCount IPv6 catch-all subnet(s) were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory subnet information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


