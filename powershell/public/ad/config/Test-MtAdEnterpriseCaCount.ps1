function Test-MtAdEnterpriseCaCount {
    <#
    .SYNOPSIS
    Counts the number of Enterprise certificate authorities configured in Active Directory.

    .DESCRIPTION
    This test retrieves the Active Directory configuration data for Enterprise CAs
    (PKI enrollment services) and reports how many are present.

    .EXAMPLE
    Test-MtAdEnterpriseCaCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdEnterpriseCaCount
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
    $enterpriseCAs = $config.EnterpriseCAs
    $enterpriseCaCount = @($enterpriseCAs).Count
    $hasData = $null -ne $config.EnterpriseCAs

    # Test passes when configuration data is available
    $testResult = $hasData -and ($enterpriseCaCount -ge 0)

    # Generate markdown results
    if ($hasData) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Enterprise CAs Count | $enterpriseCaCount |`n"
        $testResultMarkdown = "Active Directory Enterprise CAs have been counted. $enterpriseCaCount Enterprise certificate authority(s) were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory configuration data for EnterpriseCAs. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


