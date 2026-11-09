function Get-MtIntuneConfigurationPolicySetting {
    <#
    .SYNOPSIS
    Returns every setting of the Intune Windows configuration policies, one row per setting instance.

    .DESCRIPTION
    Reads the settings catalog, endpoint security and other policies of the configurationPolicies API for the
    Windows platform, with their assignments, and flattens the settings of each policy. A choice setting, a
    group collection and a simple setting each become a row; the children of a choice or a group follow it with
    the parent's setting definition ID in ParentDefinitionId, so a check can look a setting up by definition ID
    wherever it sits.

    Each row has PolicyId, PolicyName, TemplateFamily, IsAssigned, SettingDefinitionId, Value (the choice
    value or simple value, or $null for a group) and ParentDefinitionId.
    IsAssigned means the policy has at least one inclusion assignment; it does not establish which users or
    devices receive the policy or whether a setting is effective.

    .EXAMPLE
    Get-MtIntuneConfigurationPolicySetting | Where-Object SettingDefinitionId -like '*blockmacroexecutionfrominternet'

    Returns the Office macro settings of every Windows policy.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        # Only the policies of these template families, for example endpointSecurityAttackSurfaceReduction. Every Windows policy when omitted.
        [string[]] $TemplateFamily
    )

    $policies = @(Invoke-MtGraphRequest -RelativeUri "deviceManagement/configurationPolicies?`$filter=platforms has 'windows10'&`$expand=assignments" -ApiVersion beta)
    if ($TemplateFamily) { $policies = @($policies | Where-Object { $_.templateReference.templateFamily -in $TemplateFamily }) }
    Write-Verbose "Reading the settings of $($policies.Count) Intune Windows configuration policies"

    function Expand-Instance {
        param($Instance, [object] $Policy, [string] $Parent, [bool] $IsAssigned)
        if ($null -eq $Instance -or -not $Instance.settingDefinitionId) { return }
        $value = $null
        $children = @()
        if ($Instance.choiceSettingValue) {
            $value = $Instance.choiceSettingValue.value
            $children = @($Instance.choiceSettingValue.children)
        } elseif ($Instance.simpleSettingValue) {
            $value = $Instance.simpleSettingValue.value
        } elseif ($Instance.simpleSettingCollectionValue) {
            $value = @($Instance.simpleSettingCollectionValue.value)
        } elseif ($Instance.choiceSettingCollectionValue) {
            $value = @($Instance.choiceSettingCollectionValue.value)
            $children = @($Instance.choiceSettingCollectionValue.children)
        } elseif ($Instance.groupSettingCollectionValue) {
            $children = @($Instance.groupSettingCollectionValue.children)
        } elseif ($Instance.groupSettingValue) {
            $children = @($Instance.groupSettingValue.children)
        }
        [pscustomobject]@{
            PolicyId            = $Policy.id
            PolicyName          = $Policy.name
            TemplateFamily      = $Policy.templateReference.templateFamily
            IsAssigned          = $IsAssigned
            SettingDefinitionId = $Instance.settingDefinitionId
            Value               = $value
            ParentDefinitionId  = $Parent
        }
        foreach ($child in $children) { Expand-Instance -Instance $child -Policy $Policy -Parent $Instance.settingDefinitionId -IsAssigned $IsAssigned }
    }

    foreach ($policy in $policies) {
        $isAssigned = @($policy.assignments | Where-Object {
                $targetType = [string] $_.target.'@odata.type'
                $targetType -and $targetType -notmatch '(^|\.)exclusion'
            }).Count -gt 0
        $settings = @(Invoke-MtGraphRequest -RelativeUri "deviceManagement/configurationPolicies('$($policy.id)')/settings?`$top=1000" -ApiVersion beta)
        foreach ($setting in $settings) { Expand-Instance -Instance $setting.settingInstance -Policy $policy -Parent $null -IsAssigned $isAssigned }
    }
}
