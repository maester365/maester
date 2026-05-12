function Test-MtIntuneAppControl {
    <#
    .SYNOPSIS
    Ensure at least one Intune App Control for Business policy is configured.

    .DESCRIPTION
    Checks Intune Endpoint Security Application Control policies (configurationPolicies API) for
    App Control for Business (formerly WDAC) configurations.

    App Control for Business restricts which applications and drivers are allowed to run on Windows devices,
    using code integrity policies to block untrusted executables. This is one of the most effective defenses
    against malware, ransomware, and unauthorized software.

    Key settings evaluated:
    - BuildOptions: Whether built-in controls are selected or a custom XML policy is uploaded
    - PolicyXml: For uploaded policies, whether an XML policy payload is actually present
    - AuditMode: Whether the policy is in audit mode (logging only) or enforce mode
    - TrustAppsFromManagedInstaller: Whether apps deployed via Intune/SCCM are automatically trusted
    - TrustAppsWithGoodReputation: Whether ISG (Intelligent Security Graph) reputation is used

    Pass criteria:
    The test passes if at least one App Control for Business policy is **enforcing** (not audit-only) AND
    has either built-in controls selected or an uploaded XML policy with a non-empty payload.

    Audit-only policies and upload-mode policies with no XML payload are reported but do not satisfy the pass
    criterion, because they do not block untrusted executables.

    .EXAMPLE
    Test-MtIntuneAppControl

    Returns true if at least one App Control for Business policy is configured in enforce mode.

    .LINK
    https://maester.dev/docs/commands/Test-MtIntuneAppControl
    #>
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
        Write-Verbose "Querying Intune App Control for Business policies..."
        $appControlPolicies = @(Invoke-MtGraphRequest -RelativeUri "deviceManagement/configurationPolicies?`$filter=templateReference/templateFamily eq 'endpointSecurityApplicationControl'&`$select=id,name,description,templateReference" -ApiVersion beta)

        Write-Verbose "Found $($appControlPolicies.Count) App Control policies."

        if ($appControlPolicies.Count -eq 0) {
            $testResultMarkdown = "No Endpoint Security App Control for Business policies found in Intune.`n`n"
            $testResultMarkdown += "Create an App Control policy under **Endpoint Security > Application Control** to restrict "
            $testResultMarkdown += "which applications and drivers are allowed to run on managed devices."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        # Setting definition IDs
        $buildOptionsId = 'device_vendor_msft_policy_config_applicationcontrolv2_buildoptions'
        $auditModeId = 'device_vendor_msft_policy_config_applicationcontrolv2_auditmode'
        $managedInstallerId = 'device_vendor_msft_policy_config_applicationcontrolv2_trustappsfrommanagedinstaller'
        $goodReputationId = 'device_vendor_msft_policy_config_applicationcontrolv2_trustappswithgoodreputation'
        # When 'Custom policy upload' is selected, the XML payload is delivered in a simpleSettingValue child setting.
        $policyXmlId = 'device_vendor_msft_policy_config_applicationcontrolv2_policy'

        $policyResults = [System.Collections.Generic.List[hashtable]]::new()

        foreach ($policy in $appControlPolicies) {
            Write-Verbose "Checking App Control policy: $($policy.name) ($($policy.id))"
            $settingsUri = "deviceManagement/configurationPolicies('$($policy.id)')/settings?`$expand=settingDefinitions&`$top=1000"
            $settingsResponse = @(Invoke-MtGraphRequest -RelativeUri $settingsUri -ApiVersion beta)

            $policyDetail = @{
                Name              = $policy.name
                BuildOptions      = 'Not configured'
                PolicyXml         = 'N/A'
                AuditMode         = 'Not configured'
                ManagedInstaller  = 'Not configured'
                GoodReputation    = 'Not configured'
                Enforcing         = $false
                HasActiveControl  = $false
            }

            foreach ($setting in $settingsResponse) {
                $defId = $setting.settingInstance.settingDefinitionId

                if ($defId -eq $buildOptionsId) {
                    $val = $setting.settingInstance.choiceSettingValue.value
                    $isBuiltIn = $val -like '*built_in_controls_selected'
                    $isUpload = $val -like '*upload_policy_selected'
                    if ($isBuiltIn) {
                        $policyDetail.BuildOptions = 'Built-in controls'
                        $policyDetail.HasActiveControl = $true
                    } elseif ($isUpload) {
                        $policyDetail.BuildOptions = 'Custom policy upload'
                        # HasActiveControl is set later only if a non-empty XML payload is present.
                    }
                    Write-Verbose "  BuildOptions: $($policyDetail.BuildOptions)"

                    # Child settings are nested under the build options choice
                    foreach ($child in $setting.settingInstance.choiceSettingValue.children) {
                        switch ($child.settingDefinitionId) {
                            $auditModeId {
                                $childVal = $child.choiceSettingValue.value
                                if ($childVal -like '*_enabled') {
                                    $policyDetail.AuditMode = 'Enabled (audit only)'
                                    $policyDetail.Enforcing = $false
                                } else {
                                    $policyDetail.AuditMode = 'Disabled (enforcing)'
                                    $policyDetail.Enforcing = $true
                                }
                                Write-Verbose "  AuditMode: $($policyDetail.AuditMode)"
                            }
                            $managedInstallerId {
                                $childVal = $child.choiceSettingValue.value
                                $policyDetail.ManagedInstaller = if ($childVal -like '*_enabled') { 'Enabled' } else { 'Disabled' }
                                Write-Verbose "  ManagedInstaller: $($policyDetail.ManagedInstaller)"
                            }
                            $goodReputationId {
                                $childVal = $child.choiceSettingValue.value
                                $policyDetail.GoodReputation = if ($childVal -like '*_enabled') { 'Enabled' } else { 'Disabled' }
                                Write-Verbose "  GoodReputation: $($policyDetail.GoodReputation)"
                            }
                            $policyXmlId {
                                # Custom-uploaded code-integrity XML payload
                                $xmlVal = $child.simpleSettingValue.value
                                if (-not [string]::IsNullOrWhiteSpace($xmlVal)) {
                                    $policyDetail.PolicyXml = "Present ($($xmlVal.Length) chars)"
                                    if ($isUpload) { $policyDetail.HasActiveControl = $true }
                                } else {
                                    $policyDetail.PolicyXml = 'Empty'
                                }
                                Write-Verbose "  PolicyXml: $($policyDetail.PolicyXml)"
                            }
                        }
                    }
                }
            }

            $policyResults.Add($policyDetail)
        }

        # Pass: at least one policy with an active control AND in enforce mode.
        $enforcingActive = @($policyResults | Where-Object { $_.HasActiveControl -and $_.Enforcing })
        $hasEnforcingPolicy = $enforcingActive.Count -gt 0

        # Build result markdown
        $testResultMarkdown = "Found $($appControlPolicies.Count) App Control for Business policy/policies in Intune.`n`n"
        $testResultMarkdown += "**Pass criteria:** At least one App Control policy must be **enforcing** (audit mode disabled) AND have either built-in controls selected or an uploaded XML policy with a non-empty payload.`n`n"
        $testResultMarkdown += "| Policy | Build Options | Policy XML | Audit Mode | Managed Installer | ISG Reputation |`n"
        $testResultMarkdown += "| --- | --- | --- | --- | --- | --- |`n"
        foreach ($p in $policyResults) {
            $testResultMarkdown += "| $($p.Name) | $($p.BuildOptions) | $($p.PolicyXml) | $($p.AuditMode) | $($p.ManagedInstaller) | $($p.GoodReputation) |`n"
        }

        if ($hasEnforcingPolicy) {
            $testResultMarkdown += "`n**Result:** Well done. $($enforcingActive.Count) App Control for Business policy/policies are configured in **enforce mode** with active controls."

            $auditOnly = @($policyResults | Where-Object { $_.HasActiveControl -and -not $_.Enforcing })
            if ($auditOnly.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($auditOnly.Count) additional policy/policies are in **Audit mode** only. "
                $testResultMarkdown += "Audit-only policies log untrusted executables but do not block them."
            }

            $emptyUpload = @($policyResults | Where-Object { $_.BuildOptions -eq 'Custom policy upload' -and $_.PolicyXml -eq 'Empty' })
            if ($emptyUpload.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($emptyUpload.Count) policy/policies are set to **Custom policy upload** but contain no XML payload."
            }

            Add-MtTestResultDetail -Result $testResultMarkdown
            return $true
        } else {
            $testResultMarkdown += "`n**Result:** No App Control for Business policy is enforcing with an active control.`n`n"
            $testResultMarkdown += "> **Risk:** Audit-only policies and upload-mode policies with no XML payload do not block untrusted executables. "
            $testResultMarkdown += "Without an enforcing App Control policy, any executable can run on managed devices, leaving them vulnerable to malware, ransomware, and unauthorized software."
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
