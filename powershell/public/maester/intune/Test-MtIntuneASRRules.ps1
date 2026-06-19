function Test-MtIntuneASRRules {
    <#
    .SYNOPSIS
    Ensure the Microsoft Defender ASR Standard Protection baseline rules are configured in Block or Audit mode.

    .DESCRIPTION
    Checks Intune Endpoint Security Attack Surface Reduction policies (configurationPolicies API) for
    ASR rule configurations.

    ASR rules reduce the attack surface of applications by preventing behaviors commonly abused by malware,
    such as Office macros spawning child processes, credential theft from LSASS, or execution of obfuscated scripts.

    Each ASR rule can be set to one of four modes:
    - Block: Actively prevents the behavior (recommended for production)
    - Audit: Logs the event without blocking (recommended for testing)
    - Warn: Warns the user before allowing the behavior
    - Disabled/Not configured: Rule is inactive

    Pass criteria:
    The test passes if every rule in the Microsoft Defender for Endpoint ASR Standard Protection baseline is
    configured in Block or Audit mode in at least one ASR policy. The Standard Protection baseline is the
    minimum recommended set Microsoft publishes for initial ASR deployment:

    1. Block abuse of exploited vulnerable signed drivers
    2. Block credential stealing from LSASS
    3. Block persistence through WMI event subscription

    See https://learn.microsoft.com/microsoft-365/security/defender-endpoint/attack-surface-reduction-rules-deployment-implement

    Additional ASR rules detected in tenant policies are reported for visibility but do not affect the pass/fail result.

    .EXAMPLE
    Test-MtIntuneASRRules

    Returns true if every Standard Protection baseline rule is configured in Block or Audit mode across the union of all ASR policies in the tenant.

    .LINK
    https://maester.dev/docs/commands/Test-MtIntuneASRRules
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'ASR Rules is the official Microsoft product name')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        Write-Verbose "Querying Intune ASR policies..."
        $asrPolicies = @(Invoke-MtGraphRequest -RelativeUri "deviceManagement/configurationPolicies?`$filter=templateReference/templateFamily eq 'endpointSecurityAttackSurfaceReduction'&`$select=id,name,description,templateReference" -ApiVersion beta)

        Write-Verbose "Found $($asrPolicies.Count) ASR policies."

        if ($asrPolicies.Count -eq 0) {
            $testResultMarkdown = "No Endpoint Security Attack Surface Reduction policies found in Intune.`n`n"
            $testResultMarkdown += "Create an ASR policy under **Endpoint Security > Attack Surface Reduction** with "
            $testResultMarkdown += "ASR rules enabled in **Audit** or **Block** mode to protect against common attack techniques."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        # Friendly names for ASR rules (extracted from setting definition IDs)
        $asrRuleNames = @{
            'blockexecutionofpotentiallyobfuscatedscripts'                                           = 'Block execution of potentially obfuscated scripts'
            'blockwin32apicallsfromofficemacros'                                                     = 'Block Win32 API calls from Office macros'
            'blockexecutablefilesrunningunlesstheymeetprevalenceagetrustedlistcriterion'              = 'Block executable files unless they meet prevalence/age/trusted list criteria'
            'blockofficecommunicationappfromcreatingchildprocesses'                                   = 'Block Office communication app from creating child processes'
            'blockallofficeapplicationsfromcreatingchildprocesses'                                    = 'Block all Office applications from creating child processes'
            'blockadobereaderfromcreatingchildprocesses'                                              = 'Block Adobe Reader from creating child processes'
            'blockcredentialstealingfromwindowslocalsecurityauthoritysubsystem'                       = 'Block credential stealing from LSASS'
            'blockjavascriptorvbscriptfromlaunchingdownloadedexecutablecontent'                       = 'Block JavaScript/VBScript from launching downloaded executable content'
            'blockuntrustedunsignedprocessesthatrunfromusb'                                           = 'Block untrusted/unsigned processes from USB'
            'blockpersistencethroughwmieventsubscription'                                             = 'Block persistence through WMI event subscription'
            'blockuseofcopiedorimpersonatedsystemtools'                                               = 'Block use of copied or impersonated system tools'
            'blockabuseofexploitedvulnerablesigneddrivers'                                            = 'Block abuse of exploited vulnerable signed drivers'
            'blockprocesscreationsfrompsexecandwmicommands'                                           = 'Block process creations from PSExec and WMI commands'
            'blockofficeapplicationsfromcreatingexecutablecontent'                                    = 'Block Office applications from creating executable content'
            'blockofficeapplicationsfrominjectingcodeintootherprocesses'                              = 'Block Office applications from injecting code into other processes'
            'blockrebootingmachineinsafemode'                                                         = 'Block rebooting machine in Safe Mode'
            'useadvancedprotectionagainstransomware'                                                  = 'Use advanced protection against ransomware'
            'blockexecutablecontentfromemailclientandwebmail'                                         = 'Block executable content from email client and webmail'
            'blockwebshellcreationforservers'                                                         = 'Block webshell creation for servers'
        }

        # Microsoft Standard Protection baseline (minimum recommended ASR rules per Defender deployment guide).
        # Pass requires every rule in this set to be Block or Audit across the union of all ASR policies.
        $standardProtectionRuleSuffixes = @{
            'blockabuseofexploitedvulnerablesigneddrivers'                                            = 'Block abuse of exploited vulnerable signed drivers'
            'blockcredentialstealingfromwindowslocalsecurityauthoritysubsystem'                       = 'Block credential stealing from LSASS'
            'blockpersistencethroughwmieventsubscription'                                             = 'Block persistence through WMI event subscription'
        }

        $policyResults = [System.Collections.Generic.List[hashtable]]::new()
        # Track best mode seen across the union of all policies for each baseline rule.
        # Priority: Block > Audit > Warn > Disabled > Not configured.
        $baselineRuleStatus = @{}
        foreach ($k in $standardProtectionRuleSuffixes.Keys) { $baselineRuleStatus[$k] = 'Not configured' }

        $modeRank = @{ 'Block' = 4; 'Audit' = 3; 'Warn' = 2; 'Disabled' = 1; 'Not configured' = 0 }

        foreach ($policy in $asrPolicies) {
            Write-Verbose "Checking ASR policy: $($policy.name) ($($policy.id))"
            $settingsUri = "deviceManagement/configurationPolicies('$($policy.id)')/settings?`$expand=settingDefinitions&`$top=1000"
            $settingsResponse = @(Invoke-MtGraphRequest -RelativeUri $settingsUri -ApiVersion beta)

            $blockCount = 0
            $auditCount = 0
            $warnCount = 0
            $disabledCount = 0
            $notConfiguredCount = 0
            $ruleDetails = [System.Collections.Generic.List[hashtable]]::new()

            foreach ($setting in $settingsResponse) {
                $defId = $setting.settingInstance.settingDefinitionId
                if ($defId -ne 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules') { continue }

                # ASR rules are stored in a groupSettingCollectionValue
                foreach ($group in $setting.settingInstance.groupSettingCollectionValue) {
                    foreach ($child in $group.children) {
                        $childDefId = $child.settingDefinitionId
                        $val = $child.choiceSettingValue.value

                        # Extract rule name from definition ID
                        $ruleSuffix = $childDefId -replace '^device_vendor_msft_policy_config_defender_attacksurfacereductionrules_', ''
                        $friendlyName = if ($asrRuleNames.ContainsKey($ruleSuffix)) { $asrRuleNames[$ruleSuffix] } else { $ruleSuffix }

                        # Determine enforcement mode from value suffix
                        $mode = 'Not configured'
                        if ($val -like '*_block') { $mode = 'Block'; $blockCount++ }
                        elseif ($val -like '*_audit') { $mode = 'Audit'; $auditCount++ }
                        elseif ($val -like '*_warn') { $mode = 'Warn'; $warnCount++ }
                        elseif ($val -like '*_off') { $mode = 'Disabled'; $disabledCount++ }
                        else { $notConfiguredCount++ }

                        Write-Verbose "  Rule: $friendlyName = $mode"
                        $ruleDetails.Add(@{ Name = $friendlyName; Mode = $mode; IsBaseline = $standardProtectionRuleSuffixes.ContainsKey($ruleSuffix) })

                        # Track best mode for baseline rules across all policies
                        if ($standardProtectionRuleSuffixes.ContainsKey($ruleSuffix)) {
                            $current = $baselineRuleStatus[$ruleSuffix]
                            if ($modeRank[$mode] -gt $modeRank[$current]) {
                                $baselineRuleStatus[$ruleSuffix] = $mode
                            }
                        }
                    }
                }
            }

            $policyResults.Add(@{
                Name              = $policy.name
                BlockCount        = $blockCount
                AuditCount        = $auditCount
                WarnCount         = $warnCount
                DisabledCount     = $disabledCount
                NotConfiguredCount = $notConfiguredCount
                TotalRules        = $ruleDetails.Count
                Rules             = $ruleDetails
            })
        }

        # Evaluate baseline coverage across the union of all policies
        $baselineMissing = @()
        foreach ($k in $standardProtectionRuleSuffixes.Keys) {
            $mode = $baselineRuleStatus[$k]
            if ($mode -ne 'Block' -and $mode -ne 'Audit') {
                $baselineMissing += [pscustomobject]@{ Name = $standardProtectionRuleSuffixes[$k]; Mode = $mode }
            }
        }
        $baselinePassed = ($baselineMissing.Count -eq 0)

        # Build result markdown
        $testResultMarkdown = "Found $($asrPolicies.Count) Attack Surface Reduction policy/policies in Intune.`n`n"
        $testResultMarkdown += "**Pass criteria:** Every rule in the Microsoft Defender ASR Standard Protection baseline must be configured in **Block** or **Audit** mode in at least one ASR policy.`n`n"

        $testResultMarkdown += "### Standard Protection baseline coverage (across all policies)`n"
        $testResultMarkdown += "| Baseline rule | Best mode found |`n| --- | --- |`n"
        foreach ($k in $standardProtectionRuleSuffixes.Keys) {
            $testResultMarkdown += "| $($standardProtectionRuleSuffixes[$k]) | $($baselineRuleStatus[$k]) |`n"
        }
        $testResultMarkdown += "`n"

        foreach ($p in $policyResults) {
            $testResultMarkdown += "### $($p.Name)`n"
            $testResultMarkdown += "**$($p.TotalRules) rules:** $($p.BlockCount) Block, $($p.AuditCount) Audit, $($p.WarnCount) Warn, $($p.DisabledCount) Disabled, $($p.NotConfiguredCount) Not configured`n`n"
            $testResultMarkdown += "| Rule | Mode | Baseline |`n| --- | --- | --- |`n"
            foreach ($r in $p.Rules) {
                $baselineMark = if ($r.IsBaseline) { 'Yes' } else { '' }
                $testResultMarkdown += "| $($r.Name) | $($r.Mode) | $baselineMark |`n"
            }
            $testResultMarkdown += "`n"
        }

        if ($baselinePassed) {
            $testResultMarkdown += "**Result:** Well done. Every rule in the Microsoft Defender ASR Standard Protection baseline is configured in **Block** or **Audit** mode."

            # Warn about baseline rules that are still in Audit only across the tenant
            $auditOnly = @($baselineRuleStatus.Keys | Where-Object { $baselineRuleStatus[$_] -eq 'Audit' })
            if ($auditOnly.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($auditOnly.Count) baseline rule(s) are only in **Audit** mode. "
                $testResultMarkdown += "Once you have validated impact, transition them to **Block** mode for active protection."
            }

            Add-MtTestResultDetail -Result $testResultMarkdown
            return $true
        } else {
            $missingTable = ($baselineMissing | ForEach-Object { "- $($_.Name) (current: $($_.Mode))" }) -join "`n"
            $testResultMarkdown += "**Result:** The following Standard Protection baseline rules are not in Block or Audit mode:`n`n$missingTable`n`n"
            $testResultMarkdown += "> **Risk:** The Microsoft Defender ASR Standard Protection baseline is the published minimum set of rules required to mitigate "
            $testResultMarkdown += "common credential theft, driver abuse, and persistence techniques. Missing rules leave endpoints exposed to these well-known attack patterns."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }
}
