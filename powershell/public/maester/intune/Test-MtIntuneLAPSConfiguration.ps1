function Test-MtIntuneLAPSConfiguration {
    <#
    .SYNOPSIS
    Ensure at least one Intune LAPS policy is configured to back up local admin passwords to Entra ID.

    .DESCRIPTION
    Checks Intune Endpoint Security Account Protection policies (configurationPolicies API) for Windows LAPS
    profiles that back up local administrator passwords to Microsoft Entra ID (Azure AD).

    Windows LAPS (Local Administrator Password Solution) automatically rotates and backs up local admin
    passwords, preventing lateral movement attacks that exploit shared or stale local admin credentials.

    Key settings evaluated:
    - BackupDirectory: Must be set to 1 (Entra ID) to store passwords in the cloud.
    - PasswordComplexity: Recommended 4 (large letters + small letters + numbers + special characters) or 8.
    - PasswordLength: Recommended >= 14 characters.
    - AutomaticAccountManagementEnabled: Whether LAPS auto-manages the local admin account.

    The test passes if at least one LAPS policy is configured with BackupDirectory set to Entra ID.

    .EXAMPLE
    Test-MtIntuneLAPSConfiguration

    Returns true if at least one LAPS policy backs up passwords to Entra ID.

    .LINK
    https://maester.dev/docs/commands/Test-MtIntuneLAPSConfiguration
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
        # LAPS policies live under the endpointSecurityAccountProtection template family.
        # We filter by the LAPS-specific templateId prefix to exclude WHfB and other account protection policies.
        Write-Verbose "Querying Intune LAPS configuration policies..."
        $accountProtectionPolicies = @(Invoke-MtGraphRequest -RelativeUri "deviceManagement/configurationPolicies?`$filter=templateReference/templateFamily eq 'endpointSecurityAccountProtection'&`$select=id,name,description,templateReference" -ApiVersion beta)

        # Filter to LAPS policies only (templateId starts with the LAPS template)
        $lapsTemplateId = 'adc46e5a-f4aa-4ff6-aeff-4f27bc525796'
        $lapsPolicies = @($accountProtectionPolicies | Where-Object { $_.templateReference.templateId -like "$lapsTemplateId*" })

        Write-Verbose "Found $($accountProtectionPolicies.Count) Account Protection policies, $($lapsPolicies.Count) are LAPS policies."

        if ($lapsPolicies.Count -eq 0) {
            $testResultMarkdown = "No Windows LAPS policies found in Intune.`n`n"
            $testResultMarkdown += "Create a LAPS policy under **Endpoint Security > Account Protection** with "
            $testResultMarkdown += "**Backup Directory** set to **Azure AD only** to store local admin passwords in the cloud."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        # LAPS setting definition IDs
        $backupDirectoryId = 'device_vendor_msft_laps_policies_backupdirectory'
        $passwordComplexityId = 'device_vendor_msft_laps_policies_passwordcomplexity'
        $passwordLengthId = 'device_vendor_msft_laps_policies_passwordlength'
        $postAuthActionsId = 'device_vendor_msft_laps_policies_postauthenticationactions'
        $postAuthDelayId = 'device_vendor_msft_laps_policies_postauthenticationresetdelay'
        $autoAccountMgmtId = 'device_vendor_msft_laps_policies_automaticaccountmanagementenabled'

        $backupDirectoryLabels = @{
            '_0' = 'Disabled'
            '_1' = 'Azure AD only'
            '_2' = 'Active Directory'
        }

        $complexityLabels = @{
            '_1' = 'Large letters'
            '_2' = 'Large + small letters'
            '_3' = 'Large + small + numbers'
            '_4' = 'Large + small + numbers + special'
            '_8' = 'Large + small + numbers + special (improved)'
        }

        $policyResults = [System.Collections.Generic.List[hashtable]]::new()
        $hasEntraBackup = $false

        foreach ($policy in $lapsPolicies) {
            Write-Verbose "Checking LAPS policy: $($policy.name) ($($policy.id))"
            $settingsUri = "deviceManagement/configurationPolicies('$($policy.id)')/settings?`$expand=settingDefinitions&`$top=1000"
            $settingsResponse = @(Invoke-MtGraphRequest -RelativeUri $settingsUri -ApiVersion beta)

            $policyDetail = @{
                Name              = $policy.name
                BackupDirectory   = 'Not configured'
                PasswordComplexity = 'Not configured'
                PasswordLength    = 'Not configured'
                PostAuthActions   = 'Not configured'
                PostAuthDelay     = 'Not configured'
                AutoAccountMgmt   = 'Not configured'
            }

            foreach ($setting in $settingsResponse) {
                $defId = $setting.settingInstance.settingDefinitionId

                if ($defId -eq $backupDirectoryId) {
                    $val = $setting.settingInstance.choiceSettingValue.value
                    foreach ($suffix in $backupDirectoryLabels.Keys) {
                        if ($val.EndsWith($suffix)) {
                            $policyDetail.BackupDirectory = $backupDirectoryLabels[$suffix]
                            if ($suffix -eq '_1') { $hasEntraBackup = $true }
                            break
                        }
                    }
                    Write-Verbose "  BackupDirectory: $($policyDetail.BackupDirectory)"
                }

                if ($defId -eq $passwordComplexityId) {
                    $val = $setting.settingInstance.choiceSettingValue.value
                    foreach ($suffix in $complexityLabels.Keys) {
                        if ($val.EndsWith($suffix)) {
                            $policyDetail.PasswordComplexity = $complexityLabels[$suffix]
                        }
                    }
                    Write-Verbose "  PasswordComplexity: $($policyDetail.PasswordComplexity)"
                }

                if ($defId -eq $passwordLengthId) {
                    $policyDetail.PasswordLength = "$($setting.settingInstance.simpleSettingValue.value) characters"
                    Write-Verbose "  PasswordLength: $($policyDetail.PasswordLength)"
                }

                if ($defId -eq $postAuthActionsId) {
                    $val = $setting.settingInstance.choiceSettingValue.value
                    if ($val -like '*_1') { $policyDetail.PostAuthActions = 'Reset password' }
                    elseif ($val -like '*_3') { $policyDetail.PostAuthActions = 'Reset password + logoff' }
                    elseif ($val -like '*_5') { $policyDetail.PostAuthActions = 'Reset password + reboot' }
                    elseif ($val -like '*_11') { $policyDetail.PostAuthActions = 'Reset password + logoff + terminate processes' }
                    Write-Verbose "  PostAuthActions: $($policyDetail.PostAuthActions)"
                }

                if ($defId -eq $postAuthDelayId) {
                    $policyDetail.PostAuthDelay = "$($setting.settingInstance.simpleSettingValue.value) hour(s)"
                    Write-Verbose "  PostAuthDelay: $($policyDetail.PostAuthDelay)"
                }

                if ($defId -eq $autoAccountMgmtId) {
                    # The Automatic Account Management toggle may be returned as a simpleSettingValue
                    # (boolean true/false) or as a choiceSettingValue depending on how the policy was
                    # authored. Handle both shapes to avoid silently reporting 'Disabled' when enabled.
                    $simpleVal = $setting.settingInstance.simpleSettingValue.value
                    $choiceVal = $setting.settingInstance.choiceSettingValue.value
                    $val = if ($null -ne $simpleVal) { $simpleVal } else { $choiceVal }
                    $policyDetail.AutoAccountMgmt = if ($val -eq $true -or $val -like '*_true') { 'Enabled' } else { 'Disabled' }
                    Write-Verbose "  AutoAccountMgmt: $($policyDetail.AutoAccountMgmt)"
                }
            }

            $policyResults.Add($policyDetail)
        }

        # Build result markdown
        $testResultMarkdown = "Found $($lapsPolicies.Count) Windows LAPS policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | Backup Directory | Complexity | Length | Post-Auth Actions | Post-Auth Delay | Auto Account Mgmt |`n"
        $testResultMarkdown += "| --- | --- | --- | --- | --- | --- | --- |`n"
        foreach ($p in $policyResults) {
            $testResultMarkdown += "| $($p.Name) | $($p.BackupDirectory) | $($p.PasswordComplexity) | $($p.PasswordLength) | $($p.PostAuthActions) | $($p.PostAuthDelay) | $($p.AutoAccountMgmt) |`n"
        }

        if ($hasEntraBackup) {
            $testResultMarkdown += "`n**Result:** Well done. At least one LAPS policy backs up passwords to **Entra ID**."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $true
        } else {
            $testResultMarkdown += "`n**Result:** No LAPS policy is configured to back up passwords to **Entra ID**.`n`n"
            $testResultMarkdown += "> **Risk:** Without cloud backup of local admin passwords, compromised or forgotten local admin credentials "
            $testResultMarkdown += "cannot be recovered or rotated centrally, increasing lateral movement risk."
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
