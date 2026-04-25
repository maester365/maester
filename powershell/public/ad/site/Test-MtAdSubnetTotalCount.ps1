function Test-MtAdSubnetTotalCount {
    <#
    .SYNOPSIS
    Counts the total number of Active Directory subnets.

    .DESCRIPTION
    This test retrieves the total count of subnets configured in Active Directory.
    Subnets define the network boundaries for Active Directory sites and are used
    to determine which site a client belongs to for authentication and replication.

    .EXAMPLE
    Test-MtAdSubnetTotalCount

    Returns $true if subnet data is accessible.
    The test result includes the total count of subnets.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSubnetTotalCount
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
    $subnetCount = ($subnets | Measure-Object).Count

    # Test passes if we successfully retrieved subnet data
    $testResult = $subnetCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Subnets | $subnetCount |`n"

        $testResultMarkdown = "Active Directory subnets have been analyzed. There are $subnetCount subnet(s) configured in the domain.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory subnet information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
