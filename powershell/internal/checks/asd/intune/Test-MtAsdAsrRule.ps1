function Test-MtAsdAsrRule {
    <#
    .SYNOPSIS
    Checks that one Microsoft Defender attack surface reduction rule is set to Block by an assigned Intune policy.

    .DESCRIPTION
    Shared by the Essential Eight user application hardening and Microsoft Office macro checks. Reads the
    attack surface reduction rules of every Windows configuration policy (endpoint security and settings
    catalog share the setting definition IDs), takes the strongest mode any assigned policy sets for the rule,
    and passes when it is Block. Audit, Warn and Off are reported and fail: the ISM asks for the behaviour to be
    blocked, not logged.

    Writes the result detail and returns the result of the check.

    .EXAMPLE
    Test-MtAsdAsrRule -RuleSuffix 'blockallofficeapplicationsfromcreatingchildprocesses' -RuleName 'Block all Office applications from creating child processes'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The end of the rule's setting definition ID after device_vendor_msft_policy_config_defender_attacksurfacereductionrules_.
        [Parameter(Mandatory)]
        [string] $RuleSuffix,

        # The name of the rule, as the Intune admin center shows it.
        [Parameter(Mandatory)]
        [string] $RuleName
    )

    $definitionId = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_$RuleSuffix"
    $rows = @(Get-MtIntuneConfigurationPolicySetting | Where-Object { $_.SettingDefinitionId -eq $definitionId })

    $modeRank = [ordered]@{ Block = 4; Audit = 3; Warn = 2; Off = 1; 'Not configured' = 0 }
    $results = foreach ($row in $rows) {
        $mode = switch -Wildcard ([string]$row.Value) {
            '*_block' { 'Block' }
            '*_audit' { 'Audit' }
            '*_warn' { 'Warn' }
            '*_off' { 'Off' }
            default { 'Not configured' }
        }
        [pscustomobject]@{ Policy = $row.PolicyName; Mode = $mode; Assigned = $row.IsAssigned }
    }
    $results = @($results | Sort-Object { $modeRank[$_.Mode] } -Descending)
    $effective = @($results | Where-Object Assigned)
    $testResult = @($effective | Where-Object Mode -EQ 'Block').Count -gt 0

    if ($rows.Count -eq 0) {
        $testResultMarkdown = "No Intune Windows policy configures the attack surface reduction rule **$RuleName**. Add it with the mode **Block** to an Endpoint security > Attack surface reduction policy that is assigned to your workstations."
    } else {
        $table = "| Policy | Mode | Assigned |`n| --- | --- | --- |`n"
        foreach ($r in $results) { $table += "| $($r.Policy) | $($r.Mode) | $(if ($r.Assigned) { 'Yes' } else { 'No' }) |`n" }
        if ($testResult) {
            $testResultMarkdown = "Well done. An assigned Intune policy sets the attack surface reduction rule **$RuleName** to Block.`n`n$table"
        } elseif ($effective.Count -eq 0) {
            $testResultMarkdown = "The attack surface reduction rule **$RuleName** is configured, but no policy that sets it is assigned to any group or device.`n`n$table"
        } else {
            $testResultMarkdown = "No assigned Intune policy sets the attack surface reduction rule **$RuleName** to Block. Audit and Warn only report the behaviour.`n`n$table"
        }
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
