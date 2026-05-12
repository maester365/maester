function Test-MtIntuneManagedInstallerRules {
    <#
    .SYNOPSIS
    Ensure at least one Intune App Control for Business policy has Managed Installer enabled.

    .DESCRIPTION
    Checks Intune Endpoint Security Application Control policies (configurationPolicies API) for
    the "Trust apps from managed installer" setting.

    When Managed Installer is enabled in an App Control for Business policy, applications deployed through
    Intune (or SCCM) are automatically trusted and allowed to run without needing explicit allow rules.
    This simplifies App Control deployment by ensuring IT-managed software isn't blocked.

    Without Managed Installer:
    - Every application must have an explicit allow rule in the policy
    - LOB apps deployed via Intune may be blocked unexpectedly
    - Help desk tickets increase due to false positives

    With Managed Installer:
    - Apps deployed through Intune are automatically whitelisted
    - Only user-installed or sideloaded apps are subject to policy restrictions
    - Reduces false positives while maintaining security

    The test passes if at least one App Control policy is in **enforce mode** (audit mode disabled) AND has
    the "Trust apps from managed installer" setting enabled. Managed Installer enabled on an audit-only
    policy does not actively trust deployed apps because the underlying App Control policy is not enforcing.

    .EXAMPLE
    Test-MtIntuneManagedInstallerRules

    Returns true if at least one enforcing App Control policy has Managed Installer enabled.

    .LINK
    https://maester.dev/docs/commands/Test-MtIntuneManagedInstallerRules
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Managed Installer Rules is the official Microsoft product name')]
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
        Write-Verbose "Querying Intune App Control for Business policies for Managed Installer setting..."
        $appControlPolicies = @(Invoke-MtGraphRequest -RelativeUri "deviceManagement/configurationPolicies?`$filter=templateReference/templateFamily eq 'endpointSecurityApplicationControl'&`$select=id,name,description,templateReference" -ApiVersion beta)

        Write-Verbose "Found $($appControlPolicies.Count) App Control policies."

        if ($appControlPolicies.Count -eq 0) {
            $testResultMarkdown = "No Endpoint Security App Control for Business policies found in Intune.`n`n"
            $testResultMarkdown += "Create an App Control policy under **Endpoint Security > Application Control** with "
            $testResultMarkdown += "**Trust apps from managed installer** enabled to automatically trust Intune-deployed apps."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        $managedInstallerId = 'device_vendor_msft_policy_config_applicationcontrolv2_trustappsfrommanagedinstaller'

        $policyResults = [System.Collections.Generic.List[hashtable]]::new()

        foreach ($policy in $appControlPolicies) {
            Write-Verbose "Checking App Control policy: $($policy.name) ($($policy.id))"
            $settingsUri = "deviceManagement/configurationPolicies('$($policy.id)')/settings?`$expand=settingDefinitions&`$top=1000"
            $settingsResponse = @(Invoke-MtGraphRequest -RelativeUri $settingsUri -ApiVersion beta)

            $policyDetail = @{
                Name              = $policy.name
                ManagedInstaller  = 'Not configured'
                AuditMode         = 'Not configured'
                MIEnabled         = $false
                Enforcing         = $false
            }

            foreach ($setting in $settingsResponse) {
                $defId = $setting.settingInstance.settingDefinitionId

                if ($defId -eq 'device_vendor_msft_policy_config_applicationcontrolv2_buildoptions') {
                    foreach ($child in $setting.settingInstance.choiceSettingValue.children) {
                        if ($child.settingDefinitionId -eq $managedInstallerId) {
                            $childVal = $child.choiceSettingValue.value
                            if ($childVal -like '*_enabled') {
                                $policyDetail.ManagedInstaller = 'Enabled'
                                $policyDetail.MIEnabled = $true
                            } else {
                                $policyDetail.ManagedInstaller = 'Disabled'
                            }
                            Write-Verbose "  ManagedInstaller: $($policyDetail.ManagedInstaller)"
                        }
                        if ($child.settingDefinitionId -eq 'device_vendor_msft_policy_config_applicationcontrolv2_auditmode') {
                            $childVal = $child.choiceSettingValue.value
                            if ($childVal -like '*_enabled') {
                                $policyDetail.AuditMode = 'Audit'
                                $policyDetail.Enforcing = $false
                            } else {
                                $policyDetail.AuditMode = 'Enforce'
                                $policyDetail.Enforcing = $true
                            }
                            Write-Verbose "  AuditMode: $($policyDetail.AuditMode)"
                        }
                    }
                }
            }

            $policyResults.Add($policyDetail)
        }

        # Pass: at least one enforcing App Control policy with Managed Installer enabled.
        $enforcingMI = @($policyResults | Where-Object { $_.MIEnabled -and $_.Enforcing })
        $hasEnforcingMI = $enforcingMI.Count -gt 0

        # Build result markdown
        $testResultMarkdown = "Found $($appControlPolicies.Count) App Control for Business policy/policies in Intune.`n`n"
        $testResultMarkdown += "**Pass criteria:** At least one App Control policy must be in **Enforce** mode AND have **Managed Installer** enabled.`n`n"
        $testResultMarkdown += "| Policy | Managed Installer | Enforcement Mode |`n"
        $testResultMarkdown += "| --- | --- | --- |`n"
        foreach ($p in $policyResults) {
            $testResultMarkdown += "| $($p.Name) | $($p.ManagedInstaller) | $($p.AuditMode) |`n"
        }

        if ($hasEnforcingMI) {
            $testResultMarkdown += "`n**Result:** Well done. $($enforcingMI.Count) App Control policy/policies are in **Enforce** mode with **Managed Installer** enabled."
            $testResultMarkdown += " Applications deployed through Intune/SCCM will be automatically trusted."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $true
        } else {
            $auditMI = @($policyResults | Where-Object { $_.MIEnabled -and -not $_.Enforcing })
            $testResultMarkdown += "`n**Result:** No App Control policies have **Managed Installer** enabled in **Enforce** mode.`n`n"
            if ($auditMI.Count -gt 0) {
                $testResultMarkdown += "$($auditMI.Count) policy/policies have Managed Installer enabled but the underlying App Control policy is in **Audit** mode, so deployed apps are not actively trusted.`n`n"
            }
            $testResultMarkdown += "> **Risk:** Without Managed Installer on an enforcing App Control policy, applications deployed via Intune may be blocked once App Control transitions to Enforce mode. "
            $testResultMarkdown += "This leads to false positives and help desk tickets. Enable 'Trust apps from managed installer' on an enforcing policy to automatically trust IT-deployed software."
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
