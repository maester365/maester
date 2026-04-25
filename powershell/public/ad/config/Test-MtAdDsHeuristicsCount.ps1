function Test-MtAdDsHeuristicsCount {
    <#
    .SYNOPSIS
    Counts Active Directory dSHeuristics configuration settings.

    .DESCRIPTION
    Phase 14 (AD Configuration tests) - AD-CFG-02.
    This test retrieves $config.DsHeuristics and calculates the count as (string length / 2).
    If dSHeuristics is null, the count is 0.

    .EXAMPLE
    Test-MtAdDsHeuristicsCount

    Returns $true if configuration data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDsHeuristicsCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $config = $adState.Configuration
    $dsHeuristics = if ($null -ne $config) { $config.DsHeuristics } else { $null }

    $dsHeuristicsCount = if ($null -ne $dsHeuristics) { [int]($dsHeuristics.Length / 2) } else { 0 }
    $testResult = $null -ne $config

    if ($testResult) {
        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| dSHeuristics | $dsHeuristics |`n"
        $result += "| dSHeuristics Count (length/2) | $dsHeuristicsCount |`n`n"

        $testResultMarkdown = "Active Directory dSHeuristics configuration has been analyzed.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }
    else {
        $testResultMarkdown = "Unable to retrieve Active Directory configuration. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
