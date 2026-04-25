function Test-MtAdSubnetNonInternalCount {
    <#
    .SYNOPSIS
    Counts the number of non-RFC1918 (public IP) subnets in Active Directory.

    .DESCRIPTION
    This test identifies subnets that use public IP address ranges instead of
    private RFC1918 ranges. Using public IPs internally may cause routing
    issues and should be carefully evaluated.

    .EXAMPLE
    Test-MtAdSubnetNonInternalCount

    Returns $true if subnet data is accessible.
    The test result includes the count of non-internal subnets.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSubnetNonInternalCount
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

    # RFC1918 private ranges:
    # 10.0.0.0/8
    # 172.16.0.0/12 (172.16.0.0 - 172.31.255.255)
    # 192.168.0.0/16

    $nonInternalSubnets = $subnets | Where-Object {
        $subnetName = $_.Name

        # Skip IPv6 subnets for this check
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

            # 10.0.0.0/8
            if ($firstOctet -eq 10) {
                $isPrivate = $true
            }
            # 172.16.0.0/12
            elseif ($firstOctet -eq 172 -and $secondOctet -ge 16 -and $secondOctet -le 31) {
                $isPrivate = $true
            }
            # 192.168.0.0/16
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
            $result += "| Non-Internal Subnet Names | $($nonInternalSubnets.Name -join ', ') |`n"
            $result += "`n> **Note:** Non-RFC1918 subnets use public IP addresses. Ensure these are properly isolated and do not conflict with internet-routable addresses.`n"
        }

        $testResultMarkdown = "Active Directory subnet analysis has been performed. $nonInternalCount non-internal (public IP) subnet(s) were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory subnet information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
