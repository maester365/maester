function Test-MtAdSubnetFirstThreeOctetsCount {
    <#
    .SYNOPSIS
    Counts the distinct first three octets (/24 networks) used in IPv4 subnets.

    .DESCRIPTION
    This test analyzes the distribution of subnets by their first three octets,
    effectively identifying the number of /24 networks in use. This provides
    insight into the IP addressing scheme and network segmentation.

    .EXAMPLE
    Test-MtAdSubnetFirstThreeOctetsCount

    Returns $true if subnet data is accessible.
    The test result includes the count of distinct /24 networks.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSubnetFirstThreeOctetsCount
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

    # Extract first three octets from IPv4 subnets
    $firstThreeOctets = $subnets | Where-Object { $_.Name -notmatch ':' } | ForEach-Object {
        if ($_.Name -match '^([0-9]+\.[0-9]+\.[0-9]+)\.[0-9]+/[0-9]+') {
            $matches[1]
        }
    } | Select-Object -Unique | Sort-Object

    $distinctCount = ($firstThreeOctets | Measure-Object).Count
    $totalSubnets = ($subnets | Where-Object { $_.Name -notmatch ':' } | Measure-Object).Count

    # Test passes if we successfully retrieved data
    $testResult = ($subnets | Measure-Object).Count -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total IPv4 Subnets | $totalSubnets |`n"
        $result += "| Distinct /24 Networks | $distinctCount |`n"

        if ($distinctCount -gt 0 -and $distinctCount -le 20) {
            $result += "| /24 Networks Used | $($firstThreeOctets -join ', ') |`n"
        }

        $testResultMarkdown = "Active Directory subnet /24 network analysis has been performed. $distinctCount distinct /24 network(s) are in use.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory subnet information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
