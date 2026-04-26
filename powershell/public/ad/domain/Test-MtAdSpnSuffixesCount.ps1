function Test-MtAdSpnSuffixesCount {
    <#
    .SYNOPSIS
    Retrieves the count of SPN (Service Principal Name) suffixes configured in the forest.

    .DESCRIPTION
    This test retrieves the count of SPN suffixes configured in the Active Directory forest.
    SPN suffixes are used to simplify Service Principal Name management by allowing
    alternative suffixes to be used when registering SPNs for services.
    This is particularly useful in complex environments with multiple service namespaces.

    .EXAMPLE
    Test-MtAdSpnSuffixesCount

    Returns $true if SPN suffix data is accessible.
    The test result includes the count of configured SPN suffixes.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSpnSuffixesCount
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
    $spnSuffixes = $forest.SPNSuffixes
    $suffixCount = ($spnSuffixes | Measure-Object).Count

    # Test passes if we successfully retrieved forest data
    $testResult = $null -ne $spnSuffixes

    # Generate markdown results
    if ($testResult) {
        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| SPN Suffix Count | $suffixCount |`n"
        $result += "| Forest Name | $($forest.Name) |`n"

        if ($suffixCount -gt 0) {
            $result += "| SPN Suffixes | $($spnSuffixes -join ', ') |`n"
        } else {
            $result += "| SPN Suffixes | (none configured - using default forest domain) |`n"
        }

        $testResultMarkdown = "The Active Directory forest SPN suffixes have been analyzed successfully.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory SPN suffix information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


