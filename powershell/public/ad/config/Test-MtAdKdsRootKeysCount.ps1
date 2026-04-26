function Test-MtAdKdsRootKeysCount {
    <#
    .SYNOPSIS
    Counts the number of KDS root keys used for gMSA in Active Directory.

    .DESCRIPTION
    This test retrieves the KDS root keys for gMSA from the Active Directory domain configuration
    and returns the total count. KDS root keys are required for provisioning gMSA managed service
    accounts using Group Managed Service Account capabilities.

    .EXAMPLE
    Test-MtAdKdsRootKeysCount

    Returns $true if KDS root key data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdKdsRootKeysCount
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
    $kdsRootKeys = if ($null -ne $config -and $null -ne $config.KdsRootKeys) { @($config.KdsRootKeys) } else { @() }
    $kdsRootKeysCount = ($kdsRootKeys | Measure-Object).Count

    # Test passes if we successfully retrieved configuration data
    $testResult = $null -ne $config -and $null -ne $config.KdsRootKeys

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| KDS Root Keys (gMSA) | $kdsRootKeysCount |`n"

        $testResultMarkdown = "Active Directory KDS root keys have been analyzed. Found $kdsRootKeysCount KDS root key(s) for gMSA.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve KDS root key information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


