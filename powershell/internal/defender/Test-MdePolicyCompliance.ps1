function Test-MdePolicyCompliance {
    <#
    .SYNOPSIS
        Tests policy compliance for an MDE setting across all assigned policies

    .DESCRIPTION
        Analyzes configuration policies for compliance with the specified setting.
        Returns detailed compliance results categorized by compliant, non-compliant,
        and not-configured.

    .PARAMETER PolicyConfiguration
        Policy configuration hashtable from Get-MdePolicyConfiguration

    .PARAMETER SettingId
        The Intune setting definition ID to check (e.g., "device_vendor_msft_policy_config_defender_allowarchivescanning")

    .PARAMETER ComplianceCheck
        The type of compliance check: Boolean, Range, Enum, MinimumLevel, MinimumValue, NotRequired

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
        Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId "device_vendor_msft_policy_config_defender_allowarchivescanning" -ComplianceCheck "Boolean" -ExpectedValue "_1"

        Returns a hashtable with CompliantPolicies, NonCompliantPolicies, and NotConfiguredPolicies arrays.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$PolicyConfiguration,

        [Parameter(Mandatory = $true)]
        [string]$SettingId,

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

    $compliantPolicies = @()
    $nonCompliantPolicies = @()
    $notConfiguredPolicies = @()

    if ($PolicyConfiguration.ConfigurationPolicies.Count -gt 0) {
        foreach ($policy in $PolicyConfiguration.ConfigurationPolicies) {
            try {
                $settingsParams = @{
                    RelativeUri = "deviceManagement/configurationPolicies/$($policy.id)/settings"
                    ApiVersion  = 'beta'
                    ErrorAction = 'SilentlyContinue'
                }
                $policySettings = Invoke-MtGraphRequest @settingsParams

                $specificSetting = $policySettings | Where-Object {
                    $_.settingInstance.settingDefinitionId -eq $SettingId
                }

                if ($specificSetting) {
                    $settingValue = Get-MdeSettingValue -Setting $specificSetting -ComplianceCheck $ComplianceCheck

                    $complianceParams = @{
                        Value           = $settingValue
                        ComplianceCheck = $ComplianceCheck
                    }
                    if ($PSBoundParameters.ContainsKey('ExpectedValue')) { $complianceParams.ExpectedValue = $ExpectedValue }
                    if ($PSBoundParameters.ContainsKey('RangeMin')) { $complianceParams.RangeMin = $RangeMin }
                    if ($PSBoundParameters.ContainsKey('RangeMax')) { $complianceParams.RangeMax = $RangeMax }
                    if ($PSBoundParameters.ContainsKey('ValidValues')) { $complianceParams.ValidValues = $ValidValues }
                    if ($PSBoundParameters.ContainsKey('ValidLevels')) { $complianceParams.ValidLevels = $ValidLevels }
                    if ($PSBoundParameters.ContainsKey('MinimumValue')) { $complianceParams.MinimumValue = $MinimumValue }

                    $complianceResult = Test-MdeSettingCompliance @complianceParams

                    switch ($complianceResult) {
                        "Compliant" { $compliantPolicies += $policy.name }
                        "NonCompliant" { $nonCompliantPolicies += $policy.name }
                        "NotConfigured" { $notConfiguredPolicies += $policy.name }
                    }
                } elseif ($ComplianceCheck -in "NotRequired", "Manual") {
                    # Setting not present in policy - treat as compliant for non-required/manual checks
                    $compliantPolicies += $policy.name
                } else {
                    $notConfiguredPolicies += $policy.name
                }
            } catch {
                Write-Verbose "Error analyzing configuration policy $($policy.name): $($_.Exception.Message)"
                $notConfiguredPolicies += $policy.name
            }
        }
    }

    # Evaluate pass/fail based on ComplianceLogic from MDE config
    $mdeConfig = Get-MtMdeConfig
    $complianceLogic = $mdeConfig.ComplianceLogic

    switch ($complianceLogic) {
        "AnyPolicy" {
            # At least one policy must be compliant
            $isCompliant = $compliantPolicies.Count -gt 0
        }
        default {
            # "AllPolicies" (default): every policy must be compliant
            $isCompliant = ($compliantPolicies.Count -gt 0) -and ($compliantPolicies.Count -eq $PolicyConfiguration.TotalCount)
        }
    }

    return @{
        CompliantPolicies     = $compliantPolicies
        NonCompliantPolicies  = $nonCompliantPolicies
        NotConfiguredPolicies = $notConfiguredPolicies
        HasCompliant          = $compliantPolicies.Count -gt 0
        HasNonCompliant       = $nonCompliantPolicies.Count -gt 0
        HasNotConfigured      = $notConfiguredPolicies.Count -gt 0
        IsCompliant           = $isCompliant
        ComplianceLogic       = $complianceLogic
    }
}
