function Test-MdePolicyCompliance {
    <#
    .SYNOPSIS
        Tests policy compliance for an MDE setting across all assigned policies

    .DESCRIPTION
        Analyzes configuration policies for compliance with the specified setting.
        Returns detailed compliance results categorized by compliant, non-compliant,
        and not-configured.

        Tenants often split Defender Antivirus settings across several policies, so a policy
        that leaves a setting unconfigured is normal. The default 'EffectivePolicy' logic
        evaluates the combined result of the assigned policies: the setting passes when at least
        one policy configures it compliantly and no policy configures it non-compliantly. A
        policy that does not configure the setting is neutral.

        The settings these checks read do not support Intune policy merge (only the antivirus
        exclusion lists do). A compliant value in one policy and a non-compliant value in another
        therefore fail: devices that receive only the non-compliant policy are not compliant, and
        devices that receive both may get either value, or none.

        EffectivePolicy treats the policies it is given as reaching the same devices; it does not
        resolve which groups each policy is assigned to. For the same reason it does not compare
        values between compliant policies: two policies that set different values that are each
        compliant (cloud block level High and High Plus, say) pass, as they do under AllPolicies,
        although a device that receives both has an Intune conflict. With Get-MdePolicyConfiguration
        -PolicyFiltering All or IncludeUnassigned, unassigned policies count as if they were assigned.

        A Graph error while reading a policy's settings is not caught: the check ends as Error
        rather than treating the policy as unconfigured.

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

    .PARAMETER ComplianceLogic
        How the per-policy results combine into one result:
        'EffectivePolicy' (default) passes when at least one policy is compliant and none is
        non-compliant; policies that do not configure the setting are ignored. A policy that
        contains the setting with a value that cannot be evaluated counts as non-compliant.
        'AllPolicies' requires every policy to configure the setting compliantly.
        'AnyPolicy' requires at least one compliant policy and ignores the rest.

    .EXAMPLE
        Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId "device_vendor_msft_policy_config_defender_allowarchivescanning" -ComplianceCheck "Boolean" -ExpectedValue "_1"

        Returns a hashtable with CompliantPolicies, NonCompliantPolicies, and NotConfiguredPolicies arrays.

    .EXAMPLE
        Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId "device_vendor_msft_policy_config_defender_allowarchivescanning" -ComplianceCheck "Boolean" -ExpectedValue "_1" -ComplianceLogic AllPolicies

        Requires every assigned policy to enable archive scanning, the behavior before EffectivePolicy was the default.
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

        [int]$MinimumValue,

        [ValidateSet('EffectivePolicy', 'AllPolicies', 'AnyPolicy')]
        [string]$ComplianceLogic = 'EffectivePolicy'
    )

    $compliantPolicies = @()
    $nonCompliantPolicies = @()
    $notConfiguredPolicies = @()

    if ($PolicyConfiguration.ConfigurationPolicies.Count -gt 0) {
        foreach ($policy in $PolicyConfiguration.ConfigurationPolicies) {
            # A failed read must not be mistaken for an unconfigured setting: under EffectivePolicy an
            # unconfigured policy is neutral, so the check could pass on data it never saw. Let the error
            # reach the engine, which reports the check as Error with the Graph message.
            $settingsParams = @{
                RelativeUri = "deviceManagement/configurationPolicies/$($policy.id)/settings"
                ApiVersion  = 'beta'
                ErrorAction = 'Stop'
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

                # The policy sets this setting, so it is never neutral: a value that cannot be read or
                # evaluated counts against it. Manual checks keep their NotConfigured result.
                if ($complianceResult -eq 'NotConfigured' -and $ComplianceCheck -ne 'Manual') {
                    $complianceResult = 'NonCompliant'
                }

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
        }
    }

    # A compliant and a non-compliant value across policies fails: devices that receive only the non-compliant
    # policy are not compliant, and these settings do not support policy merge, so devices that receive both
    # get whichever value Intune's conflict resolution picks (most secure, then last modified, or none).
    $hasConflict = ($compliantPolicies.Count -gt 0) -and ($nonCompliantPolicies.Count -gt 0)

    switch ($ComplianceLogic) {
        "AnyPolicy" {
            # At least one policy must be compliant
            $isCompliant = $compliantPolicies.Count -gt 0
        }
        "AllPolicies" {
            # Every policy must be compliant
            $isCompliant = ($compliantPolicies.Count -gt 0) -and ($compliantPolicies.Count -eq $PolicyConfiguration.TotalCount)
        }
        default {
            # "EffectivePolicy" (default): the combined configuration must be compliant. At least one
            # policy sets a compliant value, none sets another value, and the rest leave it unconfigured.
            $isCompliant = ($compliantPolicies.Count -gt 0) -and ($nonCompliantPolicies.Count -eq 0)
        }
    }

    return @{
        CompliantPolicies     = $compliantPolicies
        NonCompliantPolicies  = $nonCompliantPolicies
        NotConfiguredPolicies = $notConfiguredPolicies
        HasCompliant          = $compliantPolicies.Count -gt 0
        HasNonCompliant       = $nonCompliantPolicies.Count -gt 0
        HasNotConfigured      = $notConfiguredPolicies.Count -gt 0
        HasConflict           = $hasConflict
        IsCompliant           = $isCompliant
        ComplianceLogic       = $ComplianceLogic
        ComplianceCheck       = $ComplianceCheck
        TotalCount            = $PolicyConfiguration.TotalCount
        PolicyFiltering       = $PolicyConfiguration.PolicyFiltering
    }
}
