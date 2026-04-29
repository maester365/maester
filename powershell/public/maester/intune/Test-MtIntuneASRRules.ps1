function Test-MtIntuneASRRules {
    <#
    .SYNOPSIS
    Ensure at least one Intune Attack Surface Reduction (ASR) policy has rules configured in Block or Audit mode.

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

    This test queries Endpoint Security ASR policies filtered by templateFamily 'endpointSecurityAttackSurfaceReduction'
    and inspects each rule's enforcement state. The test passes if at least one ASR policy has one or more rules
    configured in Block or Audit mode.

    .EXAMPLE
    Test-MtIntuneASRRules

    Returns true if at least one ASR policy has rules configured in Block or Audit mode.

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

        $policyResults = [System.Collections.Generic.List[hashtable]]::new()
        $hasActiveRules = $false

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
                        if ($val -like '*_block') { $mode = 'Block'; $blockCount++; $hasActiveRules = $true }
                        elseif ($val -like '*_audit') { $mode = 'Audit'; $auditCount++; $hasActiveRules = $true }
                        elseif ($val -like '*_warn') { $mode = 'Warn'; $warnCount++ }
                        elseif ($val -like '*_off') { $mode = 'Disabled'; $disabledCount++ }
                        else { $notConfiguredCount++ }

                        Write-Verbose "  Rule: $friendlyName = $mode"
                        $ruleDetails.Add(@{ Name = $friendlyName; Mode = $mode })
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

        # Build result markdown
        $testResultMarkdown = "Found $($asrPolicies.Count) Attack Surface Reduction policy/policies in Intune.`n`n"

        foreach ($p in $policyResults) {
            $testResultMarkdown += "### $($p.Name)`n"
            $testResultMarkdown += "**$($p.TotalRules) rules:** $($p.BlockCount) Block, $($p.AuditCount) Audit, $($p.WarnCount) Warn, $($p.DisabledCount) Disabled, $($p.NotConfiguredCount) Not configured`n`n"
            $testResultMarkdown += "| Rule | Mode |`n| --- | --- |`n"
            foreach ($r in $p.Rules) {
                $testResultMarkdown += "| $($r.Name) | $($r.Mode) |`n"
            }
            $testResultMarkdown += "`n"
        }

        if ($hasActiveRules) {
            $testResultMarkdown += "**Result:** Well done. At least one ASR policy has rules in **Block** or **Audit** mode."

            # Warn about policies with audit coverage but no block-mode rules
            $auditOnly = @($policyResults | Where-Object { $_.BlockCount -eq 0 -and $_.AuditCount -gt 0 })
            if ($auditOnly.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($auditOnly.Count) policy/policies have no rules in **Block** mode and at least one rule in **Audit** mode. "
                $testResultMarkdown += "Consider transitioning tested Audit rules to **Block** mode for active protection."
            }

            Add-MtTestResultDetail -Result $testResultMarkdown
            return $true
        } else {
            $testResultMarkdown += "**Result:** No ASR rules are configured in Block or Audit mode.`n`n"
            $testResultMarkdown += "> **Risk:** Without active ASR rules, endpoints are vulnerable to common attack techniques "
            $testResultMarkdown += "such as Office macro abuse, credential theft, and script-based attacks."
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
