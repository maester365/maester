function Test-MtAdCrossForestReferencesCount {
    <#
    .SYNOPSIS
    Retrieves the count of cross-forest references configured in the forest.

    .DESCRIPTION
    This test retrieves the count of cross-forest references in the Active Directory forest.
    Cross-forest references are objects that represent security principals from trusted external forests.
    These references enable authentication and authorization across forest boundaries.
    Understanding cross-forest references is important for assessing the security posture
    of multi-forest environments and identifying potential trust relationships.

    .EXAMPLE
    Test-MtAdCrossForestReferencesCount

    Returns $true if cross-forest reference data is accessible.
    The test result includes the count of configured cross-forest references.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdCrossForestReferencesCount
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
    $crossForestReferences = $forest.CrossForestReferences
    $referenceCount = ($crossForestReferences | Measure-Object).Count

    # Test passes if we successfully retrieved forest data
    $testResult = $null -ne $crossForestReferences

    # Generate markdown results
    if ($testResult) {
        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Cross-Forest Reference Count | $referenceCount |`n"
        $result += "| Forest Name | $($forest.Name) |`n"
        $result += "| Root Domain | $($forest.RootDomain) |`n"

        if ($referenceCount -gt 0) {
            $result += "`n**Note:** Cross-forest references exist. Review these references to ensure they represent legitimate trust relationships.`n"
        } else {
            $result += "`n**Note:** No cross-forest references found. This is expected in single-forest environments.`n"
        }

        $testResultMarkdown = "The Active Directory forest cross-forest references have been analyzed successfully.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory cross-forest reference information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


