function Test-MtAdCertificateTemplatesCount {
    <#
    .SYNOPSIS
    Counts the number of certificate templates published in Active Directory.

    .DESCRIPTION
    This test retrieves the Active Directory configuration data for certificate templates
    and reports the total number of certificate template objects present.

    .EXAMPLE
    Test-MtAdCertificateTemplatesCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdCertificateTemplatesCount
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
    $certificateTemplates = $config.CertificateTemplates
    $certificateTemplatesCount = @($certificateTemplates).Count
    $hasData = $null -ne $config.CertificateTemplates

    # Test passes when configuration data is available
    $testResult = $hasData -and ($certificateTemplatesCount -ge 0)

    # Generate markdown results
    if ($hasData) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Certificate Templates Count | $certificateTemplatesCount |`n"
        $testResultMarkdown = "Active Directory certificate templates have been counted. $certificateTemplatesCount certificate template(s) were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory configuration data for CertificateTemplates. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


