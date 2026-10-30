function Get-MtIntuneAsrRule {
    <#
    .SYNOPSIS
    Returns the Microsoft Defender attack surface reduction rules that the Intune Windows policies set, one row per policy and rule.

    .DESCRIPTION
    Reads the attack surface reduction rules of every Windows configuration policy. Endpoint security and
    settings catalog policies share the setting definition IDs, so both are read.

    Each row has Rule (the end of the setting definition ID after
    device_vendor_msft_policy_config_defender_attacksurfacereductionrules_), PolicyId, PolicyName, IsAssigned
    and Mode: Block, Audit, Warn, Off or Not configured.

    .EXAMPLE
    Get-MtIntuneAsrRule -Rule 'blockwin32apicallsfromofficemacros'

    Returns the mode that each Windows policy sets for the rule "Block Win32 API calls from Office macros".
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        # Only these rules, by the end of their setting definition ID. Every rule when omitted.
        [string[]] $Rule
    )

    $prefix = 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules_'
    foreach ($row in @(Get-MtIntuneConfigurationPolicySetting | Where-Object { $_.SettingDefinitionId.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) })) {
        $name = $row.SettingDefinitionId.Substring($prefix.Length)
        if ($Rule -and $name -notin $Rule) { continue }
        [pscustomobject]@{
            Rule       = $name
            PolicyId   = $row.PolicyId
            PolicyName = $row.PolicyName
            IsAssigned = $row.IsAssigned
            Mode       = switch -Wildcard ([string]$row.Value) {
                '*_block' { 'Block' }
                '*_audit' { 'Audit' }
                '*_warn' { 'Warn' }
                '*_off' { 'Off' }
                default { 'Not configured' }
            }
        }
    }
}
