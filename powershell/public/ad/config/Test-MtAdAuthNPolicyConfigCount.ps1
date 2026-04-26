function Test-MtAdAuthNPolicyConfigCount {
    <#
    .SYNOPSIS
    Counts Active Directory AuthN policy containers.

    .DESCRIPTION
    Phase 14 (AD Configuration tests) - AD-CFG-08.
    This test retrieves $config.AuthNPolicyContainers and returns the count of configured AuthN policy containers.

    .EXAMPLE
    Test-MtAdAuthNPolicyConfigCount

    Returns $true if configuration data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdAuthNPolicyConfigCount
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
    $authNPolicyContainers = if ($null -ne $config) { $config.AuthNPolicyContainers } else { $null }
    $authNPolicyContainersSafe = if ($null -ne $authNPolicyContainers) { @($authNPolicyContainers) } else { @() }

    $authNPolicyConfigCount = ($authNPolicyContainersSafe | Measure-Object).Count
    $testResult = $null -ne $config

    if ($testResult) {
        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| AuthN Policy Containers Count | $authNPolicyConfigCount |`n`n"

        $testResultMarkdown = "Active Directory AuthN policy containers have been counted.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }
    else {
        $testResultMarkdown = "Unable to retrieve Active Directory configuration. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}


