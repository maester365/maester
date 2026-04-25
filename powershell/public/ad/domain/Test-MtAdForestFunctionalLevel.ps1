function Test-MtAdForestFunctionalLevel {
    <#
    .SYNOPSIS
    Retrieves the current forest functional level.

    .DESCRIPTION
    This test retrieves the current forest functional level which indicates the
    features and capabilities available across all domains in the Active Directory
    forest. Higher functional levels enable advanced forest-wide security features.

    .EXAMPLE
    Test-MtAdForestFunctionalLevel

    Returns $true if forest functional level data is accessible.
    The test result includes the current forest functional level.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdForestFunctionalLevel
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

    $forest = $adState.Forest
    $functionalLevel = $forest.ForestMode

    # Test passes if we successfully retrieved forest data
    $testResult = $null -ne $functionalLevel

    # Generate markdown results
    if ($testResult) {
        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Forest Functional Level | $functionalLevel |`n"
        $result += "| Forest Name | $($forest.Name) |`n"
        $result += "| Root Domain | $($forest.RootDomain) |`n"
        $result += "| Domain Count | $($forest.Domains.Count) |`n"

        $testResultMarkdown = "The Active Directory forest functional level has been retrieved successfully.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory forest functional level. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
