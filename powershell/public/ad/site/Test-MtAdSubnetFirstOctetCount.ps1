function Test-MtAdSubnetFirstOctetCount {
    <#
    .SYNOPSIS
    Counts the distinct first octets used in IPv4 subnets.

    .DESCRIPTION
    This test analyzes the distribution of subnets by their first octet.
    This provides insight into the IP addressing scheme and network
    segmentation across the organization.

    .EXAMPLE
    Test-MtAdSubnetFirstOctetCount

    Returns $true if subnet data is accessible.
    The test result includes the count of distinct first octets.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSubnetFirstOctetCount
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

    # Extract first octets from IPv4 subnets
    $firstOctets = $subnets | Where-Object { $_.Name -notmatch ':' } | ForEach-Object {
        if ($_.Name -match '^([0-9]+)\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+') {
            [int]$matches[1]
        }
    } | Select-Object -Unique | Sort-Object

    $distinctCount = ($firstOctets | Measure-Object).Count
    $totalSubnets = ($subnets | Where-Object { $_.Name -notmatch ':' } | Measure-Object).Count

    # Test passes if we successfully retrieved data
    $testResult = ($subnets | Measure-Object).Count -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total IPv4 Subnets | $totalSubnets |`n"
        $result += "| Distinct First Octets | $distinctCount |`n"

        if ($distinctCount -gt 0) {
            $result += "| First Octets Used | $($firstOctets -join ', ') |`n"
        }

        $testResultMarkdown = "Active Directory subnet first octet analysis has been performed. $distinctCount distinct first octet(s) are in use.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory subnet information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


