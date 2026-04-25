function Test-MtAdNtAuthCertificatesCount {
    <#
    .SYNOPSIS
    Counts the NTAuth certificates configured in Active Directory.

    .DESCRIPTION
    This test retrieves the count of certificates in the NTAuthCertificates container,
    which determines which CAs are trusted for issuing smart card and domain authentication certificates.

    .EXAMPLE
    Test-MtAdNtAuthCertificatesCount

    Returns $true if NTAuth certificate data is accessible, $false otherwise.
    The test result includes the count of NTAuth certificates.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdNtAuthCertificatesCount
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
    $ntAuthCerts = $config.NtAuthCertificates
    $certCount = if ($ntAuthCerts -and $ntAuthCerts.cACertificate) { $ntAuthCerts.cACertificate.Count } else { 0 }

    # Test passes if we successfully retrieved the data
    $testResult = $null -ne $ntAuthCerts

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| NTAuth Certificates | $certCount |`n"

        $testResultMarkdown = "Active Directory NTAuth certificates have been analyzed. $certCount NTAuth certificate(s) found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve NTAuth certificate information from Active Directory. Ensure you have appropriate permissions."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
