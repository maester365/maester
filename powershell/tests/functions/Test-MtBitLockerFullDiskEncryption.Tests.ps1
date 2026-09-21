Describe 'Test-MtBitLockerFullDiskEncryption' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force

        $script:OsType = 'device_vendor_msft_bitlocker_systemdrivesencryptiontype'
        $script:OsTypeDropdown = "$($script:OsType)_osencryptiontypedropdown_name"
        $script:RequireEncryption = 'device_vendor_msft_bitlocker_requiredeviceencryption'

        # OS drive encryption type: _0 allow user to choose, _1 full encryption, _2 used space only.
        function Get-OsEncryptionTypeSetting {
            param([string] $TypeSuffix)

            return [PSCustomObject]@{
                settingInstance = [PSCustomObject]@{
                    settingDefinitionId = $script:OsType
                    choiceSettingValue  = [PSCustomObject]@{
                        value    = "$($script:OsType)_1"
                        children = @(
                            [PSCustomObject]@{
                                settingDefinitionId = $script:OsTypeDropdown
                                choiceSettingValue  = [PSCustomObject]@{ value = "$($script:OsTypeDropdown)$TypeSuffix" }
                            }
                        )
                    }
                }
            }
        }

        function Get-TestPolicy {
            param([string] $Id, [string] $Name, [string] $TemplateFamily)

            return [PSCustomObject]@{
                id                = $Id
                name              = $Name
                templateReference = [PSCustomObject]@{ templateFamily = $TemplateFamily }
            }
        }
    }

    BeforeEach {
        $script:Result = $null
        $script:SkippedBecause = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Get-MtLicenseInformation { return 'Intune Plan 1' }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause)
            $script:Result = $Result
            $script:SkippedBecause = $SkippedBecause
        }
    }

    It 'finds BitLocker full encryption configured in a Settings catalog policy' {
        # Regression: filtering on templateReference/templateFamily missed settings catalog policies.
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            param($RelativeUri)

            # '?' is a single-character wildcard for -like, so match /settings first.
            if ($RelativeUri -notlike '*/settings*') {
                $RelativeUri | Should -BeLike "*platforms has 'windows10'*"
                return @(Get-TestPolicy -Id 'cis-bl' -Name 'CIS (BL) BitLocker' -TemplateFamily 'none')
            }

            return @(Get-OsEncryptionTypeSetting -TypeSuffix '_1')
        }

        Test-MtBitLockerFullDiskEncryption | Should -Be $true
        $script:Result | Should -BeLike '*CIS (BL) BitLocker*'
        $script:Result | Should -BeLike '*Settings catalog*'
    }

    It 'ignores Disk Encryption policies that configure no BitLocker settings' {
        # Personal Data Encryption shares the endpointSecurityDiskEncryption template family.
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            param($RelativeUri)

            if ($RelativeUri -notlike '*/settings*') {
                return @(
                    (Get-TestPolicy -Id 'bl' -Name 'BitLocker' -TemplateFamily 'endpointSecurityDiskEncryption'),
                    (Get-TestPolicy -Id 'pde' -Name 'Personal Data Encryption' -TemplateFamily 'endpointSecurityDiskEncryption')
                )
            }

            if ($RelativeUri -like "*('pde')*") {
                return @([PSCustomObject]@{
                        settingInstance = [PSCustomObject]@{
                            settingDefinitionId = 'device_vendor_msft_policy_config_pde_enablepersonaldataencryption'
                        }
                    })
            }

            return @(Get-OsEncryptionTypeSetting -TypeSuffix '_1')
        }

        Test-MtBitLockerFullDiskEncryption | Should -Be $true
        $script:Result | Should -BeLike '*Found 1 BitLocker policy/policies*'
        $script:Result | Should -Not -BeLike '*Personal Data Encryption*'
        $script:Result | Should -BeLike '*Endpoint Security*'
    }

    It 'fails when the only BitLocker policy uses Used Space Only encryption' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            param($RelativeUri)

            if ($RelativeUri -notlike '*/settings*') {
                return @(Get-TestPolicy -Id 'used-space' -Name 'BitLocker used space' -TemplateFamily 'none')
            }

            return @(Get-OsEncryptionTypeSetting -TypeSuffix '_2')
        }

        Test-MtBitLockerFullDiskEncryption | Should -Be $false
        # The policy is still reported, rather than claiming no policy exists.
        $script:Result | Should -BeLike '*BitLocker used space*'
        $script:Result | Should -BeLike '*Used Space Only*'
    }

    It 'fails when no policy configures BitLocker settings' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            param($RelativeUri)

            if ($RelativeUri -notlike '*/settings*') {
                return @(Get-TestPolicy -Id 'other' -Name 'Some other policy' -TemplateFamily 'none')
            }

            return @([PSCustomObject]@{
                    settingInstance = [PSCustomObject]@{
                        settingDefinitionId = 'device_vendor_msft_policy_config_autoplay_turnoffautoplay'
                    }
                })
        }

        Test-MtBitLockerFullDiskEncryption | Should -Be $false
        $script:Result | Should -BeLike '*No BitLocker settings found*'
    }

    It 'skips when Graph is not connected' {
        Mock -ModuleName Maester Test-MtConnection { return $false }

        Test-MtBitLockerFullDiskEncryption | Should -BeNull
        $script:SkippedBecause | Should -Be 'NotConnectedGraph'
    }

    It 'skips when Intune is not licensed' {
        Mock -ModuleName Maester Get-MtLicenseInformation { return $null }

        Test-MtBitLockerFullDiskEncryption | Should -BeNull
        $script:SkippedBecause | Should -Be 'NotLicensedIntune'
    }
}
