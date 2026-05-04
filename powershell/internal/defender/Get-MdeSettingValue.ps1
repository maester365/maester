function Get-MdeSettingValue {
    <#
    .SYNOPSIS
        Extracts setting values from Graph API configuration policy responses

    .DESCRIPTION
        Parses setting objects from Microsoft Graph API configuration policy responses
        and extracts the appropriate value based on the compliance check type.

    .PARAMETER Setting
        The setting object from Graph API

    .PARAMETER ComplianceCheck
        The type of compliance check: Boolean, Range, Enum, MinimumLevel, MinimumValue, NotRequired, Manual

    .EXAMPLE
        Get-MdeSettingValue -Setting $settingObj -ComplianceCheck "Boolean"

        Returns the extracted value (e.g., "_1" for enabled).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        $Setting,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Boolean", "Range", "Enum", "MinimumLevel", "MinimumValue", "NotRequired", "Manual")]
        [string]$ComplianceCheck
    )

    switch ($ComplianceCheck) {
        "Boolean" {
            $choiceValue = $Setting.settingInstance.choiceSettingValue.value
            if ($choiceValue -match "_(\d+)$") {
                return "_$($matches[1])"
            }
            return $null
        }
        "Range" {
            return $Setting.settingInstance.simpleSettingValue.value
        }
        "Enum" {
            $choiceValue = $Setting.settingInstance.choiceSettingValue.value
            if ($choiceValue -match "_(\d+)$") {
                return "_$($matches[1])"
            }
            return $choiceValue
        }
        "MinimumLevel" {
            $choiceValue = $Setting.settingInstance.choiceSettingValue.value
            if ($choiceValue -match "_(\d+)$") {
                return "_$($matches[1])"
            }
            return $choiceValue
        }
        "MinimumValue" {
            return $Setting.settingInstance.simpleSettingValue.value
        }
        "NotRequired" {
            return "NotRequired"
        }
        "Manual" {
            return "ManualVerificationRequired"
        }
    }
}
