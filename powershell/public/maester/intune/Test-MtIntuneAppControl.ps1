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
    - BuildOptions: Whether built-in controls are selected
    - AuditMode: Whether the policy is in audit mode (logging only) or enforce mode
    - TrustAppsFromManagedInstaller: Whether apps deployed via Intune/SCCM are automatically trusted
    - TrustAppsWithGoodReputation: Whether ISG (Intelligent Security Graph) reputation is used

    The test passes if at least one App Control for Business policy exists with built-in controls configured
    or a custom policy uploaded.

    .EXAMPLE
    Test-MtIntuneAppControl

    Returns true if at least one App Control for Business policy is configured.

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

        $policyResults = [System.Collections.Generic.List[hashtable]]::new()
        $hasConfiguredPolicy = $false

        foreach ($policy in $appControlPolicies) {
            Write-Verbose "Checking App Control policy: $($policy.name) ($($policy.id))"
            $settingsUri = "deviceManagement/configurationPolicies('$($policy.id)')/settings?`$expand=settingDefinitions&`$top=1000"
            $settingsResponse = @(Invoke-MtGraphRequest -RelativeUri $settingsUri -ApiVersion beta)

            $policyDetail = @{
                Name              = $policy.name
                BuildOptions      = 'Not configured'
                AuditMode         = 'Not configured'
                ManagedInstaller  = 'Not configured'
                GoodReputation    = 'Not configured'
            }

            foreach ($setting in $settingsResponse) {
                $defId = $setting.settingInstance.settingDefinitionId

                if ($defId -eq $buildOptionsId) {
                    $val = $setting.settingInstance.choiceSettingValue.value
                    if ($val -like '*built_in_controls_selected') {
                        $policyDetail.BuildOptions = 'Built-in controls'
                        $hasConfiguredPolicy = $true
                    } elseif ($val -like '*upload_policy_selected') {
                        $policyDetail.BuildOptions = 'Custom policy upload'
                        $hasConfiguredPolicy = $true
                    }
                    Write-Verbose "  BuildOptions: $($policyDetail.BuildOptions)"

                    # Child settings are nested under the build options choice
                    foreach ($child in $setting.settingInstance.choiceSettingValue.children) {
                        if ($child.settingDefinitionId -eq $auditModeId) {
                            $childVal = $child.choiceSettingValue.value
                            $policyDetail.AuditMode = if ($childVal -like '*_enabled') { 'Enabled (audit only)' } else { 'Disabled (enforcing)' }
                            Write-Verbose "  AuditMode: $($policyDetail.AuditMode)"
                        }
                        if ($child.settingDefinitionId -eq $managedInstallerId) {
                            $childVal = $child.choiceSettingValue.value
                            $policyDetail.ManagedInstaller = if ($childVal -like '*_enabled') { 'Enabled' } else { 'Disabled' }
                            Write-Verbose "  ManagedInstaller: $($policyDetail.ManagedInstaller)"
                        }
                        if ($child.settingDefinitionId -eq $goodReputationId) {
                            $childVal = $child.choiceSettingValue.value
                            $policyDetail.GoodReputation = if ($childVal -like '*_enabled') { 'Enabled' } else { 'Disabled' }
                            Write-Verbose "  GoodReputation: $($policyDetail.GoodReputation)"
                        }
                    }
                }
            }

            $policyResults.Add($policyDetail)
        }

        # Build result markdown
        $testResultMarkdown = "Found $($appControlPolicies.Count) App Control for Business policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | Build Options | Audit Mode | Managed Installer | ISG Reputation |`n"
        $testResultMarkdown += "| --- | --- | --- | --- | --- |`n"
        foreach ($p in $policyResults) {
            $testResultMarkdown += "| $($p.Name) | $($p.BuildOptions) | $($p.AuditMode) | $($p.ManagedInstaller) | $($p.GoodReputation) |`n"
        }

        if ($hasConfiguredPolicy) {
            $testResultMarkdown += "`n**Result:** Well done. At least one App Control for Business policy is configured."

            # Warn about audit-only policies
            $auditOnly = @($policyResults | Where-Object { $_.AuditMode -eq 'Enabled (audit only)' })
            if ($auditOnly.Count -gt 0 -and $auditOnly.Count -eq $policyResults.Count) {
                $testResultMarkdown += "`n`n> **Note:** All App Control policies are in **Audit mode**. "
                $testResultMarkdown += "Consider transitioning to **Enforce mode** after validating that legitimate applications are not blocked."
            }

            Add-MtTestResultDetail -Result $testResultMarkdown
            return $true
        } else {
            $testResultMarkdown += "`n**Result:** No App Control policies have active configurations.`n`n"
            $testResultMarkdown += "> **Risk:** Without App Control, any executable can run on managed devices, "
            $testResultMarkdown += "leaving them vulnerable to malware, ransomware, and unauthorized software."
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
