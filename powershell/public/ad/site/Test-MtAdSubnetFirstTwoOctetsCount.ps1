function Test-MtAdSubnetFirstTwoOctetsCount {
    <#
    .SYNOPSIS
    Counts the distinct first two octets (/16 networks) used in IPv4 subnets.

    .DESCRIPTION
    This test analyzes the distribution of subnets by their first two octets,
    effectively identifying the number of /16 networks in use. This provides
    insight into the IP addressing scheme and network segmentation.

    .EXAMPLE
    Test-MtAdSubnetFirstTwoOctetsCount

    Returns $true if subnet data is accessible.
    The test result includes the count of distinct /16 networks.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSubnetFirstTwoOctetsCount
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

    # Extract first two octets from IPv4 subnets
    $firstTwoOctets = $subnets | Where-Object { $_.Name -notmatch ':' } | ForEach-Object {
        if ($_.Name -match '^([0-9]+\.[0-9]+)\.[0-9]+\.[0-9]+/[0-9]+') {
            $matches[1]
        }
    } | Select-Object -Unique | Sort-Object

    $distinctCount = ($firstTwoOctets | Measure-Object).Count
    $totalSubnets = ($subnets | Where-Object { $_.Name -notmatch ':' } | Measure-Object).Count

    # Test passes if we successfully retrieved data
    $testResult = ($subnets | Measure-Object).Count -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total IPv4 Subnets | $totalSubnets |`n"
        $result += "| Distinct /16 Networks | $distinctCount |`n"

        if ($distinctCount -gt 0 -and $distinctCount -le 20) {
            $result += "| /16 Networks Used | $($firstTwoOctets -join ', ') |`n"
        }

        $testResultMarkdown = "Active Directory subnet /16 network analysis has been performed. $distinctCount distinct /16 network(s) are in use.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory subnet information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


