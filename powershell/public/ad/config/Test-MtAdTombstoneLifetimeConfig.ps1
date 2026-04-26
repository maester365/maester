function Test-MtAdTombstoneLifetimeConfig {
    <#
    .SYNOPSIS
    Returns the Active Directory tombstone lifetime configuration.

    .DESCRIPTION
    Phase 14 (AD Configuration tests) - AD-CFG-01.
    This test retrieves the tombstone lifetime (in days) from $adState.Configuration.

    .EXAMPLE
    Test-MtAdTombstoneLifetimeConfig

    Returns $true if configuration data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTombstoneLifetimeConfig
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
    $tombstoneLifetime = if ($null -ne $config) { $config.TombstoneLifetime } else { $null }

    $testResult = $null -ne $config

    if ($testResult) {
        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Tombstone Lifetime (days) | $tombstoneLifetime |`n`n"

        $testResultMarkdown = "Active Directory tombstone lifetime configuration has been retrieved.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }
    else {
        $testResultMarkdown = "Unable to retrieve Active Directory configuration. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}


