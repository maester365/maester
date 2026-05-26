function Test-MtBitLockerFullDiskEncryptionCompliance {
    <#
    .SYNOPSIS
    Ensure at least one Intune Disk Encryption policy enforces BitLocker with full disk encryption type.

    .DESCRIPTION
    Checks Intune Endpoint Security Disk Encryption policies (configurationPolicies API) for BitLocker
    profiles that enforce full disk encryption rather than "Used space only" encryption.

    BitLocker supports two encryption types with very different security implications:
    - "Full disk encryption" -- encrypts the entire drive including free space. This is the secure option.
    - "Used space only encryption" -- only encrypts sectors currently holding data. Previously deleted
      files that were written before encryption was enabled remain in unencrypted free space and can be
      recovered using data recovery software (e.g., Recuva, PhotoRec, or forensic tools). This is because
      NTFS marks sectors as free but does not zero them out -- the raw data stays on disk until overwritten.

    This test queries the configurationPolicies Graph API (used by Endpoint Security > Disk Encryption)
    which exposes the actual BitLocker CSP settings including:
    - SystemDrivesEncryptionType (OS drive encryption type: full vs used space only)
    - FixedDrivesEncryptionType (fixed drive encryption type: full vs used space only)
    - RequireDeviceEncryption (require BitLocker encryption)
    - EncryptionMethodByDriveType (cipher strength: XTS-AES 128/256, AES-CBC 128/256)

    The test passes only if at least one BitLocker Disk Encryption policy has the OS drive encryption
    type set to "Full encryption". It fails if no policies exist, if encryption type is set to
    "Used space only", or if the encryption type setting is not configured.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtBitLockerFullDiskEncryptionCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    # Phase 2: Data Collection & Phase 3: Compliance Validation

    try {
        # Query Endpoint Security Disk Encryption policies (server-side filter).
        # This template family can include non-BitLocker templates (e.g., Personal Data Encryption);
        # BitLocker-specific settings are evaluated per-policy below.
        Write-Verbose "Querying Intune Endpoint Security Disk Encryption policies..."
        $diskEncryptionPolicies = @(Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/deviceManagement/configurationPolicies?`$filter=templateReference/templateFamily eq 'endpointSecurityDiskEncryption'&`$select=id,name,description,templateReference" -ApiVersion beta)

        if ($diskEncryptionPolicies.Count -eq 0) {
            return $false
        }

        # Setting definition IDs for BitLocker CSP settings
        $osEncryptionTypeId = 'device_vendor_msft_bitlocker_systemdrivesencryptiontype'
        $osEncryptionTypeDropdownId = 'device_vendor_msft_bitlocker_systemdrivesencryptiontype_osencryptiontypedropdown_name'
        $fixedEncryptionTypeId = 'device_vendor_msft_bitlocker_fixeddrivesencryptiontype'
        $fixedEncryptionTypeDropdownId = 'device_vendor_msft_bitlocker_fixeddrivesencryptiontype_fdeencryptiontypedropdown_name'
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

        foreach ($policy in $diskEncryptionPolicies) {
            # Fetch settings for this policy with definitions expanded
            $settingsUri = "deviceManagement/configurationPolicies('$($policy.id)')/settings?`$expand=settingDefinitions&`$top=1000"
            $settingsResponse = @(Invoke-MtGraphRequest -RelativeUri $settingsUri -ApiVersion beta)

            $policyDetail = @{
                Name               = $policy.name
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

            $policyResults.Add($policyDetail)
        }

        # Filter to only BitLocker policies (those with BitLocker CSP settings)
        $bitLockerPolicies = @($policyResults | Where-Object { $_.IsBitLockerPolicy })

        if ($bitLockerPolicies.Count -eq 0) {
            return $false
        }

        # Build result markdown (only BitLocker policies)
        if ($hasFullEncryption) {

            # Warn if any policy uses Used Space Only
            $usedSpaceOnly = @($bitLockerPolicies | Where-Object { $_.OsEncryptionType -eq 'Used Space Only' })
            if ($usedSpaceOnly.Count -gt 0) {
            }

            return $true
        } else {
            return $false
        }
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
        } else {
        }
        return $null
    }

}
