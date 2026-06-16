function Test-MtIntuneLAPSConfiguration {
    <#
    .SYNOPSIS
    Ensure at least one Intune LAPS policy is configured to back up local admin passwords to Entra ID.

    .DESCRIPTION
    Checks Intune Endpoint Security Account Protection policies (configurationPolicies API) for Windows LAPS
    profiles that back up local administrator passwords to Microsoft Entra ID (Azure AD).

    Windows LAPS (Local Administrator Password Solution) automatically rotates and backs up local admin
    passwords, preventing lateral movement attacks that exploit shared or stale local admin credentials.

    Pass criteria (all required on at least one LAPS policy):
    - BackupDirectory = 1 (Entra ID) to store passwords in the cloud.
    - PasswordComplexity >= 4 (large + small letters + numbers + special characters; values 4 or 8 are accepted).
    - PasswordLength >= 14 characters.
    - PostAuthenticationActions configured to a non-zero value (reset password, optionally logoff/reboot/terminate).

    AutomaticAccountManagementEnabled is reported for completeness but does not affect pass/fail.

    The test passes if at least one LAPS policy meets all four criteria above.

    .EXAMPLE
    Test-MtIntuneLAPSConfiguration

    Returns true if at least one LAPS policy meets the secure baseline (Entra ID backup, complexity >= 4, length >= 14, post-auth action configured).

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

        # Pass-criteria thresholds
        $minPasswordLength = 14
        $minComplexitySuffixes = @('_4', '_8')   # 4-class or improved 4-class
        $validPostAuthSuffixes = @('_1', '_3', '_5', '_11')

        $policyResults = [System.Collections.Generic.List[hashtable]]::new()
        $hasCompliantPolicy = $false

        foreach ($policy in $lapsPolicies) {
            Write-Verbose "Checking LAPS policy: $($policy.name) ($($policy.id))"
            $settingsUri = "deviceManagement/configurationPolicies('$($policy.id)')/settings?`$expand=settingDefinitions&`$top=1000"
            $settingsResponse = @(Invoke-MtGraphRequest -RelativeUri $settingsUri -ApiVersion beta)

            $policyDetail = @{
                Name               = $policy.name
                BackupDirectory    = 'Not configured'
                PasswordComplexity = 'Not configured'
                PasswordLength     = 'Not configured'
                PostAuthActions    = 'Not configured'
                PostAuthDelay      = 'Not configured'
                AutoAccountMgmt    = 'Not configured'
                Compliant          = 'No'
            }

            $hasEntra = $false
            $hasComplexity = $false
            $hasLength = $false
            $hasPostAuth = $false

            foreach ($setting in $settingsResponse) {
                $defId = $setting.settingInstance.settingDefinitionId

                if ($defId -eq $backupDirectoryId) {
                    $val = $setting.settingInstance.choiceSettingValue.value
                    foreach ($suffix in $backupDirectoryLabels.Keys) {
                        if ($val.EndsWith($suffix)) {
                            $policyDetail.BackupDirectory = $backupDirectoryLabels[$suffix]
                            if ($suffix -eq '_1') { $hasEntra = $true }
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
                    foreach ($suffix in $minComplexitySuffixes) {
                        if ($val -and $val.EndsWith($suffix)) { $hasComplexity = $true; break }
                    }
                    Write-Verbose "  PasswordComplexity: $($policyDetail.PasswordComplexity)"
                }

                if ($defId -eq $passwordLengthId) {
                    $lengthVal = [int]($setting.settingInstance.simpleSettingValue.value)
                    $policyDetail.PasswordLength = "$lengthVal characters"
                    if ($lengthVal -ge $minPasswordLength) { $hasLength = $true }
                    Write-Verbose "  PasswordLength: $($policyDetail.PasswordLength)"
                }

                if ($defId -eq $postAuthActionsId) {
                    $val = $setting.settingInstance.choiceSettingValue.value
                    if ($val -like '*_1') { $policyDetail.PostAuthActions = 'Reset password' }
                    elseif ($val -like '*_3') { $policyDetail.PostAuthActions = 'Reset password + logoff' }
                    elseif ($val -like '*_5') { $policyDetail.PostAuthActions = 'Reset password + reboot' }
                    elseif ($val -like '*_11') { $policyDetail.PostAuthActions = 'Reset password + logoff + terminate processes' }
                    foreach ($suffix in $validPostAuthSuffixes) {
                        if ($val -and $val.EndsWith($suffix)) { $hasPostAuth = $true; break }
                    }
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

            if ($hasEntra -and $hasComplexity -and $hasLength -and $hasPostAuth) {
                $policyDetail.Compliant = 'Yes'
                $hasCompliantPolicy = $true
            }

            $policyResults.Add($policyDetail)
        }

        # Build result markdown
        $testResultMarkdown = "Found $($lapsPolicies.Count) Windows LAPS policy/policies in Intune.`n`n"
        $testResultMarkdown += "**Pass criteria:** Entra ID backup + Complexity >= 4-class + Length >= $minPasswordLength + Post-auth action configured.`n`n"
        $testResultMarkdown += "| Policy | Backup Directory | Complexity | Length | Post-Auth Actions | Post-Auth Delay | Auto Account Mgmt | Meets baseline |`n"
        $testResultMarkdown += "| --- | --- | --- | --- | --- | --- | --- | --- |`n"
        foreach ($p in $policyResults) {
            $testResultMarkdown += "| $($p.Name) | $($p.BackupDirectory) | $($p.PasswordComplexity) | $($p.PasswordLength) | $($p.PostAuthActions) | $($p.PostAuthDelay) | $($p.AutoAccountMgmt) | $($p.Compliant) |`n"
        }

        if ($hasCompliantPolicy) {
            $testResultMarkdown += "`n**Result:** Well done. At least one LAPS policy meets the secure baseline (Entra ID backup, complexity, length, and post-auth action)."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $true
        } else {
            $testResultMarkdown += "`n**Result:** No LAPS policy meets all four baseline requirements (Entra ID backup, complexity >= 4-class, length >= $minPasswordLength, post-auth action).`n`n"
            $testResultMarkdown += "> **Risk:** A LAPS policy that misses any of these settings provides reduced protection. Weak complexity or short passwords are easier to brute force; "
            $testResultMarkdown += "without cloud backup, compromised local admin credentials cannot be rotated centrally; without a post-authentication action, a stolen password remains valid."
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
