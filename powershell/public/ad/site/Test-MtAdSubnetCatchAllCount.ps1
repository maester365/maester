function Test-MtAdSubnetCatchAllCount {
    <#
    .SYNOPSIS
    Counts the number of catch-all subnets (overly broad RFC1918 ranges).

    .DESCRIPTION
    This test identifies subnets that are configured with overly broad IP ranges
    that could encompass multiple physical locations. Catch-all subnets like
    10.0.0.0/8 or 172.16.0.0/12 may cause clients to authenticate to distant DCs.

    .EXAMPLE
    Test-MtAdSubnetCatchAllCount

    Returns $true if subnet data is accessible.
    The test result includes the count of catch-all subnets.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSubnetCatchAllCount
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

    # Define catch-all patterns (overly broad RFC1918 ranges)
    $catchAllPatterns = @(
        '^10\.0\.0\.0/8$',
        '^172\.16\.0\.0/12$',
        '^192\.168\.0\.0/16$',
        '^10\.[0-9]+\.0\.0/16$',
        '^172\.(1[6-9]|2[0-9]|3[0-1])\.0\.0/16$'
    )

    # Find catch-all subnets
    $catchAllSubnets = $subnets | Where-Object {
        $subnetName = $_.Name
        foreach ($pattern in $catchAllPatterns) {
            if ($subnetName -match $pattern) {
                return $true
            }
        }
        return $false
    }

    $catchAllCount = ($catchAllSubnets | Measure-Object).Count

    # Test passes if we successfully retrieved data
    $testResult = $totalSubnets -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Subnets | $totalSubnets |`n"
        $result += "| Catch-All Subnets | $catchAllCount |`n"

        if ($catchAllCount -gt 0) {
            $result += "| Catch-All Subnet Names | $($catchAllSubnets.Name -join ', ') |`n"
            $result += "`n> **Warning:** Catch-all subnets may cause clients to authenticate to distant domain controllers. Consider using more specific subnet definitions.`n"
        }

        $testResultMarkdown = "Active Directory subnet analysis has been performed. $catchAllCount catch-all subnet(s) were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory subnet information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
