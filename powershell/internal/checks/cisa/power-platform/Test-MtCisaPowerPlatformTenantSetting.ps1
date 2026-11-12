function Test-MtCisaPowerPlatformTenantSetting {
    <#
    .SYNOPSIS
    Evaluates a Power Platform tenant setting that must be true for a CISA SCuBA check.

    .DESCRIPTION
    Reads one Boolean tenant setting from the Power Platform admin API, records the observed value, and returns true
    when it is true. A missing or non-Boolean value is an error rather than a failed audit, because the baseline cannot
    be assessed without it.

    .EXAMPLE
    Test-MtCisaPowerPlatformTenantSetting -SettingName 'disableEnvironmentCreationByNonAdminUsers' -SettingTitle 'Production and sandbox environment creation is restricted to administrators'

    Returns true when only administrators can create production and sandbox environments.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Dot-separated path of the Boolean tenant setting, for example powerPlatform.powerApps.disableShareWithEveryone.
        [Parameter(Mandatory)]
        [string] $SettingName,

        # Sentence-style description of the restriction the setting enforces, without a trailing period.
        [Parameter(Mandatory)]
        [string] $SettingTitle
    )

    $value = Get-MtPowerPlatformTenantSetting
    foreach ($segment in $SettingName.Split('.')) {
        $property = if ($null -eq $value) { $null } else { $value.PSObject.Properties[$segment] }
        if ($null -eq $property) {
            throw "Power Platform tenant setting '$SettingName' was not returned by the tenant settings API."
        }

        $value = $property.Value
    }

    if ($value -isnot [bool]) {
        throw "Power Platform tenant setting '$SettingName' did not have a Boolean value."
    }

    $resultText = if ($value) { 'Pass' } else { 'Fail' }
    $resultMd = "| Setting | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    $resultMd += "| ``$SettingName`` | $value | $resultText |`n"

    if ($value) {
        $message = "Well done. $SettingTitle."
    }
    else {
        $message = "$SettingTitle is not enforced. Set ``$SettingName`` to ``true``."
    }

    Add-MtTestResultDetail -Result "$message`n`n$resultMd"
    return $value
}
