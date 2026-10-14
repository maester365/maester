function Test-MdeSettingCompliance {
    <#
    .SYNOPSIS
        Tests compliance for a specific MDE setting value

    .DESCRIPTION
        Evaluates a setting value against compliance criteria to determine
        if it meets requirements. Returns "Compliant", "NonCompliant", or "NotConfigured".

    .PARAMETER Value
        The setting value to test

    .PARAMETER ComplianceCheck
        The type of compliance check to perform

    .PARAMETER ExpectedValue
        The expected value for Boolean checks

    .PARAMETER RangeMin
        Minimum value for Range checks

    .PARAMETER RangeMax
        Maximum value for Range checks

    .PARAMETER ValidValues
        Array of valid values for Enum checks

    .PARAMETER ValidLevels
        Hashtable mapping values to numeric levels for MinimumLevel checks

    .PARAMETER MinimumValue
        Minimum numeric value for MinimumValue and MinimumLevel checks

    .EXAMPLE
        Test-MdeSettingCompliance -Value "_1" -ComplianceCheck "Boolean" -ExpectedValue "_1"

        Returns "Compliant"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        $Value,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Boolean", "Range", "Enum", "MinimumLevel", "MinimumValue", "NotRequired", "Manual")]
        [string]$ComplianceCheck,

        [string]$ExpectedValue,

        [int]$RangeMin,

        [int]$RangeMax,

        [string[]]$ValidValues,

        [hashtable]$ValidLevels,

        [int]$MinimumValue
    )

    if ($null -eq $Value -or $Value -eq "") {
        return "NotConfigured"
    }

    switch ($ComplianceCheck) {
        "Boolean" {
            if ([string]$Value -eq [string]$ExpectedValue) {
                return "Compliant"
            } else {
                return "NonCompliant"
            }
        }
        "Range" {
            try {
                $numValue = [int]$Value
                if ($numValue -ge $RangeMin -and $numValue -le $RangeMax) {
                    return "Compliant"
                } else {
                    return "NonCompliant"
                }
            } catch {
                return "NonCompliant"
            }
        }
        "Enum" {
            if ([string]$Value -in $ValidValues) {
                return "Compliant"
            } else {
                return "NonCompliant"
            }
        }
        "MinimumLevel" {
            if ($ValidLevels -and $ValidLevels.ContainsKey([string]$Value)) {
                $actualLevel = $ValidLevels[[string]$Value]
                if ($actualLevel -ge $MinimumValue) {
                    return "Compliant"
                } else {
                    return "NonCompliant"
                }
            } else {
                return "NonCompliant"
            }
        }
        "MinimumValue" {
            try {
                $numValue = [int]$Value
                if ($numValue -ge $MinimumValue) {
                    return "Compliant"
                } else {
                    return "NonCompliant"
                }
            } catch {
                return "NonCompliant"
            }
        }
        "NotRequired" {
            return "Compliant"
        }
        "Manual" {
            return "NotConfigured"
        }
        default {
            return "NotConfigured"
        }
    }
}
