function Test-MtAdTrustedRootCaCount {
    <#
    .SYNOPSIS
    Counts the trusted root certificate authorities configured in Active Directory.

    .DESCRIPTION
    This test retrieves the count of trusted root CAs from the Certification Authorities
    container in Active Directory. Root CAs are the trust anchors for the PKI infrastructure.

    .EXAMPLE
    Test-MtAdTrustedRootCaCount

    Returns $true if trusted root CA data is accessible, $false otherwise.
    The test result includes the count of trusted root CAs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTrustedRootCaCount
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
    $rootCAs = $config.TrustedRootCAs
    $caCount = ($rootCAs | Measure-Object).Count

    # Test passes if we successfully retrieved the data
    $testResult = $null -ne $rootCAs

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Trusted Root CAs | $caCount |`n"

        $testResultMarkdown = "Active Directory trusted root CAs have been analyzed. $caCount trusted root CA(s) found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve trusted root CA information from Active Directory. Ensure you have appropriate permissions."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
