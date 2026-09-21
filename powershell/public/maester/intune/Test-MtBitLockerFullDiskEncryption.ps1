function Test-MtBitLockerFullDiskEncryption {
    <#
    .SYNOPSIS
    Ensure at least one Intune Disk Encryption policy enforces BitLocker with full disk encryption type.

    .DESCRIPTION
    Checks Intune Windows configuration policies (configurationPolicies API) for BitLocker settings
    that enforce full disk encryption rather than "Used space only" encryption. Covers both Endpoint
    Security Disk Encryption profiles and Settings catalog policies.

    BitLocker supports two encryption types with very different security implications:
    - "Full disk encryption" -- encrypts the entire drive including free space. This is the secure option.
    - "Used space only encryption" -- only encrypts sectors currently holding data. Previously deleted
      files that were written before encryption was enabled remain in unencrypted free space and can be
      recovered using data recovery software (e.g., Recuva, PhotoRec, or forensic tools). This is because
      NTFS marks sectors as free but does not zero them out -- the raw data stays on disk until overwritten.

    This test queries the configurationPolicies Graph API, which exposes the actual BitLocker CSP
    settings including:
    - SystemDrivesEncryptionType (OS drive encryption type: full vs used space only)
    - FixedDrivesEncryptionType (fixed drive encryption type: full vs used space only)
    - RequireDeviceEncryption (require BitLocker encryption)
    - EncryptionMethodByDriveType (cipher strength: XTS-AES 128/256, AES-CBC 128/256)

    The test passes only if at least one BitLocker policy has the OS drive encryption type set to
    "Full encryption". It fails if no BitLocker settings exist in any policy, if encryption type is
    set to "Used space only", or if the encryption type setting is not configured.

    .EXAMPLE
    Test-MtBitLockerFullDiskEncryption

    Returns true if at least one Disk Encryption policy enforces full disk encryption for OS drives.

    .LINK
    https://maester.dev/docs/commands/Test-MtBitLockerFullDiskEncryption
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
        # BitLocker settings carry visibility 'settingsCatalog,template', so they can be configured
        # from either Endpoint Security > Disk Encryption or the Settings catalog. Filtering on
        # template family misses the latter, so identify BitLocker policies by their settings.
        Write-Verbose "Querying Intune Windows configuration policies..."
        $candidatePolicies = @(Invoke-MtGraphRequest -RelativeUri "deviceManagement/configurationPolicies?`$filter=platforms has 'windows10'&`$select=id,name,description,templateReference" -ApiVersion beta)

        Write-Verbose "Found $($candidatePolicies.Count) Windows configuration policies to inspect."

        # Setting definition IDs for BitLocker CSP settings
        $osEncryptionTypeId = 'device_vendor_msft_bitlocker_systemdrivesencryptiontype'
        $osEncryptionTypeDropdownId = 'device_vendor_msft_bitlocker_systemdrivesencryptiontype_osencryptiontypedropdown_name'
        $fixedEncryptionTypeId = 'device_vendor_msft_bitlocker_fixeddrivesencryptiontype'
        $fixedEncryptionTypeDropdownId = 'device_vendor_msft_bitlocker_fixeddrivesencryptiontype_fdvencryptiontypedropdown_name'
        $requireEncryptionId = 'device_vendor_msft_bitlocker_requiredeviceencryption'
        $encryptionMethodId = 'device_vendor_msft_bitlocker_encryptionmethodbydrivetype'
        $osEncryptionMethodDropdownId = 'device_vendor_msft_bitlocker_encryptionmethodbydrivetype_encryptionmethodwithxtsosdropdown_name'

        # Encryption type value suffixes: _0 = Allow user to choose, _1 = Full encryption, _2 = Used Space Only
        $encryptionTypeLabels = @{
            '_0' = 'Allow user to choose'
            '_1' = 'Full encryption'
            '_2' = 'Used Space Only'
        }

        # Encryption method value suffixes: _3=AES-CBC 128, _4=AES-CBC 256, _6=XTS-AES 128, _7=XTS-AES 256
        $encryptionMethodLabels = @{
            '_3' = 'AES-CBC 128-bit'
            '_4' = 'AES-CBC 256-bit'
            '_6' = 'XTS-AES 128-bit'
            '_7' = 'XTS-AES 256-bit'
        }

        $policyResults = [System.Collections.Generic.List[hashtable]]::new()
        $hasFullEncryption = $false

        foreach ($policy in $candidatePolicies) {
            # Fetch settings for this policy with definitions expanded
            $settingsUri = "deviceManagement/configurationPolicies('$($policy.id)')/settings?`$expand=settingDefinitions&`$top=1000"
            $settingsResponse = @(Invoke-MtGraphRequest -RelativeUri $settingsUri -ApiVersion beta)

            $policyDetail = @{
                Name               = $policy.name
                Source             = if ($policy.templateReference.templateFamily -eq 'endpointSecurityDiskEncryption') { 'Endpoint Security' } else { 'Settings catalog' }
                RequireEncryption  = 'Not configured'
                OsEncryptionType   = 'Not configured'
                FixedEncryptionType = 'Not configured'
                OsEncryptionMethod = 'Not configured'
                IsBitLockerPolicy  = $false
            }

            foreach ($setting in $settingsResponse) {
                $defId = $setting.settingInstance.settingDefinitionId

                # Check RequireDeviceEncryption
                if ($defId -eq $requireEncryptionId) {
                    $policyDetail.IsBitLockerPolicy = $true
                    $val = $setting.settingInstance.choiceSettingValue.value
                    if ($val -like '*_1') {
                        $policyDetail.RequireEncryption = 'Enabled'
                    } else {
                        $policyDetail.RequireEncryption = 'Disabled'
                    }
                }

                # Check OS drive encryption type (SystemDrivesEncryptionType)
                if ($defId -eq $osEncryptionTypeId) {
                    $policyDetail.IsBitLockerPolicy = $true
                    $parentVal = $setting.settingInstance.choiceSettingValue.value
                    if ($parentVal -like '*_1') {
                        # Enabled -- check the child dropdown for the actual encryption type
                        $children = $setting.settingInstance.choiceSettingValue.children
                        foreach ($child in $children) {
                            if ($child.settingDefinitionId -eq $osEncryptionTypeDropdownId) {
                                $dropdownVal = $child.choiceSettingValue.value
                                foreach ($suffix in $encryptionTypeLabels.Keys) {
                                    if ($dropdownVal.EndsWith($suffix)) {
                                        $policyDetail.OsEncryptionType = $encryptionTypeLabels[$suffix]
                                        if ($suffix -eq '_1') { $hasFullEncryption = $true }
                                    }
                                }
                            }
                        }
                    }
                }

                # Check Fixed drive encryption type (FixedDrivesEncryptionType)
                if ($defId -eq $fixedEncryptionTypeId) {
                    $policyDetail.IsBitLockerPolicy = $true
                    $parentVal = $setting.settingInstance.choiceSettingValue.value
                    if ($parentVal -like '*_1') {
                        $children = $setting.settingInstance.choiceSettingValue.children
                        foreach ($child in $children) {
                            if ($child.settingDefinitionId -eq $fixedEncryptionTypeDropdownId) {
                                $dropdownVal = $child.choiceSettingValue.value
                                foreach ($suffix in $encryptionTypeLabels.Keys) {
                                    if ($dropdownVal.EndsWith($suffix)) {
                                        $policyDetail.FixedEncryptionType = $encryptionTypeLabels[$suffix]
                                    }
                                }
                            }
                        }
                    }
                }

                # Check encryption method (cipher strength)
                if ($defId -eq $encryptionMethodId) {
                    $policyDetail.IsBitLockerPolicy = $true
                    $parentVal = $setting.settingInstance.choiceSettingValue.value
                    if ($parentVal -like '*_1') {
                        $children = $setting.settingInstance.choiceSettingValue.children
                        foreach ($child in $children) {
                            if ($child.settingDefinitionId -eq $osEncryptionMethodDropdownId) {
                                $methodVal = $child.choiceSettingValue.value
                                foreach ($suffix in $encryptionMethodLabels.Keys) {
                                    if ($methodVal.EndsWith($suffix)) {
                                        $policyDetail.OsEncryptionMethod = $encryptionMethodLabels[$suffix]
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if (-not $policyDetail.IsBitLockerPolicy) { continue }
            $policyResults.Add($policyDetail)
        }

        $bitLockerPolicies = @($policyResults)

        if ($bitLockerPolicies.Count -eq 0) {
            $testResultMarkdown = "No BitLocker settings found in any Intune Windows configuration policy.`n`n"
            $testResultMarkdown += "Create a BitLocker policy under **Endpoint Security > Disk Encryption** with "
            $testResultMarkdown += "**Enforce drive encryption type** set to **Full encryption** for OS and fixed data drives."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        $testResultMarkdown = "Found $($bitLockerPolicies.Count) BitLocker policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | Configured via | Require Encryption | OS Encryption Type | Fixed Encryption Type | OS Cipher |`n"
        $testResultMarkdown += "| --- | --- | --- | --- | --- | --- |`n"
        foreach ($p in $bitLockerPolicies) {
            $testResultMarkdown += "| $($p.Name) | $($p.Source) | $($p.RequireEncryption) | $($p.OsEncryptionType) | $($p.FixedEncryptionType) | $($p.OsEncryptionMethod) |`n"
        }

        if ($hasFullEncryption) {
            $testResultMarkdown += "`n**Result:** At least one BitLocker policy enforces **Full encryption** for OS drives."

            # Warn if any policy uses Used Space Only
            $usedSpaceOnly = @($bitLockerPolicies | Where-Object { $_.OsEncryptionType -eq 'Used Space Only' })
            if ($usedSpaceOnly.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Warning:** $($usedSpaceOnly.Count) policy/policies use **Used Space Only** encryption. "
                $testResultMarkdown += "Previously deleted data remains recoverable from unencrypted free space on those devices."
            }

            Add-MtTestResultDetail -Result $testResultMarkdown
            return $true
        } else {
            $testResultMarkdown += "`n**Result:** No BitLocker policy enforces **Full encryption** for OS drives.`n`n"
            $testResultMarkdown += "> **Risk:** If 'Used space only' encryption is configured (or encryption type is not enforced), "
            $testResultMarkdown += "data written to the disk before BitLocker was enabled remains as raw unencrypted data in free space "
            $testResultMarkdown += "and can be recovered using commonly available data recovery tools (Recuva, PhotoRec, forensic imaging)."
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
