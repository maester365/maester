function Test-MtAdAdActivationObjectsCount {
    <#
    .SYNOPSIS
    Counts Active Directory activation objects from configuration.

    .DESCRIPTION
    Phase 14 (AD Configuration tests) - AD-CFG-09.
    This test retrieves $config.ActivationObjects and returns the count of AD-based activation objects.

    .EXAMPLE
    Test-MtAdAdActivationObjectsCount

    Returns $true if configuration data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdAdActivationObjectsCount
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
    $activationObjects = if ($null -ne $config) { $config.ActivationObjects } else { $null }
    $activationObjectsSafe = if ($null -ne $activationObjects) { @($activationObjects) } else { @() }

    $activationObjectsCount = ($activationObjectsSafe | Measure-Object).Count
    $testResult = $null -ne $config

    if ($testResult) {
        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Activation Objects Count | $activationObjectsCount |`n`n"

        $testResultMarkdown = "Active Directory activation objects have been counted.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }
    else {
        $testResultMarkdown = "Unable to retrieve Active Directory configuration. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
