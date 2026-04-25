function Test-MtAdCrlDistributionPointsCount {
    <#
    .SYNOPSIS
    Counts the CRL distribution points configured in Active Directory.

    .DESCRIPTION
    This test retrieves the count of CRL (Certificate Revocation List) distribution points
    configured in the Active Directory Public Key Services container. CRL distribution points
    are essential for publishing certificate revocation information.

    .EXAMPLE
    Test-MtAdCrlDistributionPointsCount

    Returns $true if CRL distribution point data is accessible, $false otherwise.
    The test result includes the count of CRL distribution points.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdCrlDistributionPointsCount
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

    $config = $adState.Configuration
    $cdpObjects = $config.CrlDistributionPoints
    $cdpCount = ($cdpObjects | Measure-Object).Count

    # Test passes if we successfully retrieved the data
    $testResult = $null -ne $cdpObjects

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| CRL Distribution Points | $cdpCount |`n"

        $testResultMarkdown = "Active Directory CRL distribution points have been analyzed. $cdpCount CRL distribution point(s) found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve CRL distribution point information from Active Directory. Ensure you have appropriate permissions."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
