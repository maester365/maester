function Test-MtAdSubnetNonInternalDetails {
    <#
    .SYNOPSIS
    Lists the non-RFC1918 (public IP) subnets in Active Directory.

    .DESCRIPTION
    This test provides detailed information about subnets that use public IP
    address ranges instead of private RFC1918 ranges. Using public IPs
    internally may cause routing issues and should be carefully evaluated.

    .EXAMPLE
    Test-MtAdSubnetNonInternalDetails

    Returns $true if subnet data is accessible.
    The test result includes detailed information about non-internal subnets.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSubnetNonInternalDetails
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

    # Identify non-RFC1918 subnets
    $nonInternalSubnets = $subnets | Where-Object {
        $subnetName = $_.Name

        # Skip IPv6 subnets
        if ($subnetName -match ':') {
            return $false
        }

        # Extract the IP address part
        if ($subnetName -match '^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/[0-9]+') {
            $ip = $matches[1]
            $octets = $ip -split '\.'
            $firstOctet = [int]$octets[0]
            $secondOctet = [int]$octets[1]

            # Check if it's NOT in RFC1918 ranges
            $isPrivate = $false

            if ($firstOctet -eq 10) {
                $isPrivate = $true
            }
            elseif ($firstOctet -eq 172 -and $secondOctet -ge 16 -and $secondOctet -le 31) {
                $isPrivate = $true
            }
            elseif ($firstOctet -eq 192 -and $secondOctet -eq 168) {
                $isPrivate = $true
            }

            return -not $isPrivate
        }

        return $false
    }

    $nonInternalCount = ($nonInternalSubnets | Measure-Object).Count

    # Test passes if we successfully retrieved data
    $testResult = $totalSubnets -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Subnets | $totalSubnets |`n"
        $result += "| Non-Internal (Public IP) Subnets | $nonInternalCount |`n"

        if ($nonInternalCount -gt 0) {
            $result += "`n### Non-Internal (Public IP) Subnets`n`n"
            $result += "| Subnet | Site | Description |`n"
            $result += "| --- | --- | --- |`n"

            foreach ($subnet in ($nonInternalSubnets | Sort-Object Name)) {
                $siteName = if ($subnet.SiteObject) {
                    ($subnet.SiteObject -split ',')[0] -replace '^CN=', ''
                } else { "Unassigned" }
                $description = if ($subnet.Description) { $subnet.Description } else { "N/A" }
                $result += "| $($subnet.Name) | $siteName | $description |`n"
            }

            $result += "`n> **Note:** Non-RFC1918 subnets use public IP addresses. Ensure these are properly isolated and do not conflict with internet-routable addresses.`n"
        } else {
            $result += "`n✅ All subnets use RFC1918 private IP ranges.`n"
        }

        $testResultMarkdown = "Active Directory non-internal subnet analysis has been performed.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory subnet information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
