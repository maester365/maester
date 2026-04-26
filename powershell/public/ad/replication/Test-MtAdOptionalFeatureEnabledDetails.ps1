function Test-MtAdOptionalFeatureEnabledDetails {
    <#
    .SYNOPSIS
    Retrieves detailed information about enabled Active Directory optional features.

    .DESCRIPTION
    Active Directory optional features can be enabled at different scopes
    (forest or domain level). This test provides detailed information about
    which optional features are enabled and their scope of application.

    Key optional features to monitor:
    - Recycle Bin: Critical for object recovery, should be enabled
    - PAM: Privileged Access Management for time-based access
    - Other features relevant to your security requirements

    .EXAMPLE
    Test-MtAdOptionalFeatureEnabledDetails

    Returns $true if optional feature data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdOptionalFeatureEnabledDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $optionalFeatures = $adState.OptionalFeatures
    $enabledFeatures = $optionalFeatures | Where-Object { $_.EnabledScopes.Count -gt 0 }
    $enabledCount = ($enabledFeatures | Measure-Object).Count

    $testResult = $true

    $result = "| Property | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Optional Features | $(($optionalFeatures | Measure-Object).Count) |`n"
    $result += "| Enabled Features | $enabledCount |`n"

    if ($enabledCount -gt 0) {
        $result += "`n**Enabled Feature Details:**`n`n"
        $result += "| Feature Name | Enabled Scopes |`n"
        $result += "| --- | --- |`n"
        foreach ($feature in $enabledFeatures) {
            $scopeCount = $feature.EnabledScopes.Count
            $result += "| $($feature.Name) | $scopeCount scope(s) |`n"
        }
    }

    $testResultMarkdown = "Active Directory optional feature details have been retrieved. Enabled features extend AD functionality.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


