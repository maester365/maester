function Test-MtCisFabricTenantSetting {
    <#
    .SYNOPSIS
    Evaluates a Microsoft Fabric tenant setting for a CIS check.

    .DESCRIPTION
    Reads one validated tenant setting, applies its audit rule, records the observed state, and returns a Boolean result.

    .EXAMPLE
    Test-MtCisFabricTenantSetting -SettingName 'ElevatedGuestsTenant' -SettingTitle 'Guest users can browse Fabric content' -Rule DisabledOrGroups

    Returns true when guest browsing is disabled or limited to one or more security groups.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SettingName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SettingTitle,

        [Parameter(Mandatory)]
        [ValidateSet('DisabledOrGroups', 'PublishToWeb', 'Disabled', 'Enabled')]
        [string] $Rule
    )

    $settings = @(Get-MtFabricTenantSettings | Where-Object { $_.settingName -eq $SettingName })
    if ($settings.Count -ne 1) {
        throw "Expected exactly one Fabric tenant setting named '$SettingName'; received $($settings.Count)."
    }

    $setting = $settings[0]
    if ($setting.enabled -isnot [bool]) {
        throw "Fabric tenant setting '$SettingName' did not include a Boolean enabled value."
    }

    $isEnabled = $setting.enabled -eq $true
    $isDisabled = -not $isEnabled
    $groupProperty = $setting.PSObject.Properties['enabledSecurityGroups']
    $enabledGroups = if ($null -eq $groupProperty) { @() } else { @($groupProperty.Value | Where-Object { $_ }) }
    $hasGroups = $enabledGroups.Count -gt 0
    $scope = if ($isDisabled) { 'Not applicable' } elseif ($hasGroups) { "$($enabledGroups.Count) security group(s)" } else { 'Entire organization' }
    $additionalCondition = 'Not applicable'
    $createP2wIsBoolean = $false
    $createP2wIsDisabled = $false

    if ($Rule -eq 'PublishToWeb' -and $isEnabled) {
        $propertiesProperty = $setting.PSObject.Properties['properties']
        $createP2wProperty = if ($null -eq $propertiesProperty -or $null -eq $propertiesProperty.Value) {
            $null
        } else {
            $propertiesProperty.Value.PSObject.Properties['createP2w']
        }

        $createP2wIsBoolean = $null -ne $createP2wProperty -and $createP2wProperty.Value -is [bool]
        $createP2wIsDisabled = $createP2wIsBoolean -and -not $createP2wProperty.Value
        $additionalCondition = if (-not $createP2wIsBoolean) {
            'Not found or invalid'
        } elseif ($createP2wIsDisabled) {
            'Existing codes only'
        } else {
            'New codes allowed'
        }
    }

    switch ($Rule) {
        'DisabledOrGroups' {
            $testResult = $isDisabled -or ($isEnabled -and $hasGroups)
        }
        'PublishToWeb' {
            $testResult = $isDisabled -or ($isEnabled -and $hasGroups -and $createP2wIsDisabled)
        }
        'Disabled' {
            $testResult = $isDisabled
        }
        'Enabled' {
            $testResult = $isEnabled
        }
    }

    $stateText = if ($isDisabled) { 'disabled' } elseif ($hasGroups) { "enabled for $($enabledGroups.Count) security group(s)" } else { 'enabled for the entire organization' }
    if ($Rule -eq 'PublishToWeb' -and $testResult -and $isEnabled) {
        $stateText += ' with only existing embed codes allowed'
    }

    $resultText = if ($testResult) { 'Pass' } else { 'Fail' }
    $enabledText = if ($isEnabled) { 'True' } else { 'False' }
    $resultMd = "| Setting | Enabled | Scope | Additional condition | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- |`n"
    $resultMd += "| $SettingTitle | $enabledText | $scope | $additionalCondition | $resultText |`n"

    if ($testResult) {
        $resultMessage = "Well done. $SettingTitle is $stateText."
    } else {
        $resultMessage = switch ($Rule) {
            'DisabledOrGroups' { "$SettingTitle is enabled for the entire organization. Disable it or restrict it to one or more security groups." }
            'PublishToWeb' {
                $restrictionsToFix = @()
                if (-not $hasGroups) { $restrictionsToFix += 'restrict it to one or more security groups' }
                if (-not $createP2wIsBoolean) {
                    $restrictionsToFix += 'confirm that new embed codes are disabled'
                } elseif (-not $createP2wIsDisabled) {
                    $restrictionsToFix += 'allow only existing embed codes'
                }
                "$SettingTitle does not meet the required restrictions. Set it to " + ($restrictionsToFix -join ' and ') + '.'
            }
            'Disabled' { "$SettingTitle is enabled. Disable it in Fabric tenant settings." }
            'Enabled' { "$SettingTitle is disabled. Enable it in Fabric tenant settings." }
        }
    }

    Add-MtTestResultDetail -Result "$resultMessage`n`n$resultMd"
    return [bool] $testResult
}