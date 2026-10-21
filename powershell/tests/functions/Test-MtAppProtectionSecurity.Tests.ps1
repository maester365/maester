Describe 'iOS and Android Intune app protection checks' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # The helper is internal and the check functions are native tests, so none of them is exported.
        Use-MtModuleFunction -Name Get-MtAppProtectionPolicy,
        Test-MtIosAppProtectionPinPolicy, Test-MtIosAppProtectionDataTransfer,
        Test-MtIosAppProtectionEncryption, Test-MtIosAppProtectionMinimumVersions,
        Test-MtIosAppProtectionOfflineGracePeriod, Test-MtIosAppProtectionDeviceThreatLevel,
        Test-MtAndroidAppProtectionPinPolicy, Test-MtAndroidAppProtectionDataTransfer,
        Test-MtAndroidAppProtectionEncryption, Test-MtAndroidAppProtectionMinimumVersions,
        Test-MtAndroidAppProtectionOfflineGracePeriod, Test-MtAndroidAppProtectionDeviceThreatLevel,
        Test-MtAndroidAppProtectionScreenCapture, Test-MtAndroidAppProtectionDeviceAttestation

        function Get-TestIosPolicy {
            # An iOS app protection policy as the helper returns it. The defaults satisfy every check,
            # so each test flips exactly the setting it is about. Thresholds are untyped so that a test
            # can pass $null, which is what Intune returns for a setting that was never configured.
            param(
                [string] $Name = 'iOS App Protection',
                [int] $AssignmentCount = 1,
                [bool] $IsAssignedFlag = $true,
                [bool] $PinRequired = $true,
                $MinimumPinLength = 6,
                $MaximumPinRetries = 5,
                [bool] $SimplePinBlocked = $true,
                [bool] $DisableAppPinIfDevicePinIsSet = $false,
                $OutboundDataTransfer = 'managedApps',
                $ClipboardSharingLevel = 'managedAppsWithPasteIn',
                [bool] $SaveAsBlocked = $true,
                [bool] $DataBackupBlocked = $true,
                $MinimumRequiredOsVersion = '18.0',
                $MinimumRequiredAppVersion = '4.2.0',
                $MinimumRequiredSdkVersion = '',
                $OfflineBeforeAccessCheckHours = 12,
                $OfflineBeforeWipeDays = 90,
                $MaximumDeviceThreatLevel = 'secured',
                $ThreatRemediationAction = 'block',
                $AppDataEncryptionType = 'whenDeviceLocked'
            )

            return [pscustomobject]@{
                Id                            = [guid]::NewGuid().ToString()
                Name                          = $Name
                Platform                      = 'iOS'
                PolicyType                    = 'iosManagedAppProtection'
                AssignmentCount               = $AssignmentCount
                IsAssignedFlag                = $IsAssignedFlag
                IsAssigned                    = ($AssignmentCount -gt 0 -or $IsAssignedFlag)
                AssignmentSignalsDisagree     = (($AssignmentCount -gt 0) -ne $IsAssignedFlag)
                AppGroupType                  = 'allCoreMicrosoftApps'
                DeployedAppCount              = 12
                PinRequired                   = $PinRequired
                MinimumPinLength              = $MinimumPinLength
                MaximumPinRetries             = $MaximumPinRetries
                SimplePinBlocked              = $SimplePinBlocked
                PinCharacterSet               = 'numeric'
                DisableAppPinIfDevicePinIsSet = $DisableAppPinIfDevicePinIsSet
                OutboundDataTransfer          = $OutboundDataTransfer
                InboundDataTransfer           = 'allApps'
                ClipboardSharingLevel         = $ClipboardSharingLevel
                SaveAsBlocked                 = $SaveAsBlocked
                DataBackupBlocked             = $DataBackupBlocked
                PrintBlocked                  = $true
                MinimumRequiredOsVersion      = $MinimumRequiredOsVersion
                MinimumRequiredAppVersion     = $MinimumRequiredAppVersion
                OfflineBeforeAccessCheck      = 'PT12H'
                OfflineBeforeAccessCheckHours = $OfflineBeforeAccessCheckHours
                OfflineBeforeWipe             = 'P90D'
                OfflineBeforeWipeDays         = $OfflineBeforeWipeDays
                MaximumDeviceThreatLevel      = $MaximumDeviceThreatLevel
                ThreatRemediationAction       = $ThreatRemediationAction
                DeviceComplianceRequired      = $false
                AppDataEncryptionType         = $AppDataEncryptionType
                MinimumRequiredSdkVersion     = $MinimumRequiredSdkVersion
                FaceIdBlocked                 = $false
                ThirdPartyKeyboardsBlocked    = $true
            }
        }

        function Get-TestAndroidPolicy {
            # The Android counterpart. Same contract, plus the Android-only settings.
            param(
                [string] $Name = 'Android App Protection',
                [int] $AssignmentCount = 1,
                [bool] $IsAssignedFlag = $true,
                [bool] $PinRequired = $true,
                $MinimumPinLength = 6,
                $MaximumPinRetries = 5,
                [bool] $SimplePinBlocked = $true,
                [bool] $DisableAppPinIfDevicePinIsSet = $false,
                $OutboundDataTransfer = 'managedApps',
                $ClipboardSharingLevel = 'managedAppsWithPasteIn',
                [bool] $SaveAsBlocked = $true,
                [bool] $DataBackupBlocked = $true,
                $MinimumRequiredOsVersion = '14',
                $MinimumRequiredAppVersion = '4.2.0',
                $MinimumRequiredPatchVersion = '2025-01-01',
                $OfflineBeforeAccessCheckHours = 12,
                $OfflineBeforeWipeDays = 90,
                $MaximumDeviceThreatLevel = 'secured',
                $ThreatRemediationAction = 'block',
                [bool] $EncryptAppData = $true,
                [bool] $AppEncryptionDisabledByDeviceEncryption = $false,
                [bool] $ScreenCaptureBlocked = $true,
                $DeviceAttestationType = 'basicIntegrityAndDeviceCertification',
                $ActionIfAttestationFailed = 'block'
            )

            return [pscustomobject]@{
                Id                                      = [guid]::NewGuid().ToString()
                Name                                    = $Name
                Platform                                = 'Android'
                PolicyType                              = 'androidManagedAppProtection'
                AssignmentCount                         = $AssignmentCount
                IsAssignedFlag                          = $IsAssignedFlag
                IsAssigned                              = ($AssignmentCount -gt 0 -or $IsAssignedFlag)
                AssignmentSignalsDisagree               = (($AssignmentCount -gt 0) -ne $IsAssignedFlag)
                AppGroupType                            = 'allCoreMicrosoftApps'
                DeployedAppCount                        = 12
                PinRequired                             = $PinRequired
                MinimumPinLength                        = $MinimumPinLength
                MaximumPinRetries                       = $MaximumPinRetries
                SimplePinBlocked                        = $SimplePinBlocked
                PinCharacterSet                         = 'numeric'
                DisableAppPinIfDevicePinIsSet           = $DisableAppPinIfDevicePinIsSet
                OutboundDataTransfer                    = $OutboundDataTransfer
                InboundDataTransfer                     = 'allApps'
                ClipboardSharingLevel                   = $ClipboardSharingLevel
                SaveAsBlocked                           = $SaveAsBlocked
                DataBackupBlocked                       = $DataBackupBlocked
                PrintBlocked                            = $true
                MinimumRequiredOsVersion                = $MinimumRequiredOsVersion
                MinimumRequiredAppVersion               = $MinimumRequiredAppVersion
                OfflineBeforeAccessCheck                = 'PT12H'
                OfflineBeforeAccessCheckHours           = $OfflineBeforeAccessCheckHours
                OfflineBeforeWipe                       = 'P90D'
                OfflineBeforeWipeDays                   = $OfflineBeforeWipeDays
                MaximumDeviceThreatLevel                = $MaximumDeviceThreatLevel
                ThreatRemediationAction                 = $ThreatRemediationAction
                DeviceComplianceRequired                = $false
                EncryptAppData                          = $EncryptAppData
                AppEncryptionDisabledByDeviceEncryption = $AppEncryptionDisabledByDeviceEncryption
                ScreenCaptureBlocked                    = $ScreenCaptureBlocked
                DeviceAttestationType                   = $DeviceAttestationType
                ActionIfAttestationFailed               = $ActionIfAttestationFailed
                DeviceLockRequired                      = $true
                MinimumRequiredPatchVersion             = $MinimumRequiredPatchVersion
            }
        }

        function New-EmptyPolicyList {
            # Mirror the real helper: emit an empty list without unrolling it to $null.
            Write-Output ([System.Collections.Generic.List[pscustomobject]]::new()) -NoEnumerate
        }

        function New-GraphAppProtectionPolicy {
            # A policy in the raw shape Graph returns, for the helper's own tests.
            param(
                $Id = ([guid]::NewGuid().ToString()),
                $DisplayName = 'Graph policy',
                $OdataType = '#microsoft.graph.iosManagedAppProtection',
                $Assignments = @([pscustomobject]@{ id = 'assignment-1' }),
                $IsAssigned = $true,
                $PeriodOfflineBeforeAccessCheck = 'PT12H',
                $PeriodOfflineBeforeWipeIsEnforced = 'P90D',
                $MinimumPinLength = 6,
                $MaximumPinRetries = 5,
                $PinRequired = $true,
                $EncryptAppData = $true,
                $DisableAppEncryptionIfDeviceEncryptionIsEnabled = $false
            )

            return [pscustomobject]@{
                'id'                                              = $Id
                'displayName'                                     = $DisplayName
                '@odata.type'                                     = $OdataType
                'assignments'                                     = $Assignments
                'isAssigned'                                      = $IsAssigned
                'periodOfflineBeforeAccessCheck'                  = $PeriodOfflineBeforeAccessCheck
                'periodOfflineBeforeWipeIsEnforced'               = $PeriodOfflineBeforeWipeIsEnforced
                'minimumPinLength'                                = $MinimumPinLength
                'maximumPinRetries'                               = $MaximumPinRetries
                'pinRequired'                                     = $PinRequired
                'encryptAppData'                                  = $EncryptAppData
                'disableAppEncryptionIfDeviceEncryptionIsEnabled' = $DisableAppEncryptionIfDeviceEncryptionIsEnabled
            }
        }
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null
        $script:Investigate = $false

        Mock -ModuleName Maester Get-MtLicenseInformation { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $Investigate)

            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
            $script:Investigate = [bool] $Investigate
        }
    }

    Context 'Language behaviour the threshold guards exist for' {
        # These two assertions are the reason every threshold in these checks is compared only after an
        # explicit $null check, and why durations are compared as parsed numbers and never as strings.
        It 'passes an unconfigured maximum when it is compared naively' {
            ($null -le 5) | Should -BeTrue
            ($null -le 15) | Should -BeTrue
        }

        It 'reads twelve hours as under a two-hour limit when durations are compared as strings' {
            ('PT12H' -le 'PT2H') | Should -BeTrue
            ($null -le 'PT12H') | Should -BeTrue
        }

        It 'fails closed in the other direction, which is why minimums are guarded for reporting only' {
            ($null -ge 6) | Should -BeFalse
        }
    }

    Context 'Get-MtAppProtectionPolicy' {
        It 'reads the iOS collection for -Platform iOS' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @(New-GraphAppProtectionPolicy) }

            Get-MtAppProtectionPolicy -Platform iOS | Out-Null

            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter {
                $RelativeUri -eq 'deviceAppManagement/iosManagedAppProtections' -and $ApiVersion -eq 'beta'
            }
        }

        It 'reads the Android collection for -Platform Android' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @(New-GraphAppProtectionPolicy -OdataType '#microsoft.graph.androidManagedAppProtection') }

            Get-MtAppProtectionPolicy -Platform Android | Out-Null

            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter {
                $RelativeUri -eq 'deviceAppManagement/androidManagedAppProtections'
            }
        }

        It 'expands the assignments, which are not returned by default' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @(New-GraphAppProtectionPolicy) }

            Get-MtAppProtectionPolicy -Platform iOS | Out-Null

            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter {
                $QueryParameters.expand -eq 'assignments'
            }
        }

        It 'returns null when the policies could not be read at all' {
            # A failed Invoke-MtGraphRequest collects as one element with no id.
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @($null) }

            $null -eq (Get-MtAppProtectionPolicy -Platform iOS) | Should -BeTrue
        }

        It 'returns an empty list, not null, for a tenant with no policies' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

            $result = Get-MtAppProtectionPolicy -Platform iOS

            $null -eq $result | Should -BeFalse
            $result.Count | Should -Be 0
        }

        It 'parses the two durations into hours and days' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @(New-GraphAppProtectionPolicy -PeriodOfflineBeforeAccessCheck 'PT8H' -PeriodOfflineBeforeWipeIsEnforced 'P30D')
            }

            $policy = (Get-MtAppProtectionPolicy -Platform iOS)[0]

            $policy.OfflineBeforeAccessCheckHours | Should -Be 8
            $policy.OfflineBeforeWipeDays | Should -Be 30
            $policy.OfflineBeforeAccessCheck | Should -Be 'PT8H'
        }

        It 'leaves an unparseable duration null and keeps the raw value' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @(New-GraphAppProtectionPolicy -PeriodOfflineBeforeAccessCheck 'not-a-duration')
            }

            $policy = (Get-MtAppProtectionPolicy -Platform iOS)[0]

            $null -eq $policy.OfflineBeforeAccessCheckHours | Should -BeTrue
            $policy.OfflineBeforeAccessCheck | Should -Be 'not-a-duration'
        }

        It 'leaves an absent duration null rather than zero' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @(New-GraphAppProtectionPolicy -PeriodOfflineBeforeAccessCheck $null -PeriodOfflineBeforeWipeIsEnforced $null)
            }

            $policy = (Get-MtAppProtectionPolicy -Platform iOS)[0]

            $null -eq $policy.OfflineBeforeAccessCheckHours | Should -BeTrue
            $null -eq $policy.OfflineBeforeWipeDays | Should -BeTrue
        }

        It 'leaves an absent threshold null rather than zero' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @(New-GraphAppProtectionPolicy -MinimumPinLength $null -MaximumPinRetries $null)
            }

            $policy = (Get-MtAppProtectionPolicy -Platform iOS)[0]

            $null -eq $policy.MinimumPinLength | Should -BeTrue
            $null -eq $policy.MaximumPinRetries | Should -BeTrue
        }

        It 'counts a policy as assigned when only the isAssigned property says so' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @(New-GraphAppProtectionPolicy -Assignments @() -IsAssigned $true)
            }

            $policy = (Get-MtAppProtectionPolicy -Platform iOS)[0]

            $policy.IsAssigned | Should -BeTrue
            $policy.AssignmentCount | Should -Be 0
            $policy.AssignmentSignalsDisagree | Should -BeTrue
        }

        It 'counts a policy as assigned when only the expanded assignments say so' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @(New-GraphAppProtectionPolicy -IsAssigned $false)
            }

            $policy = (Get-MtAppProtectionPolicy -Platform iOS)[0]

            $policy.IsAssigned | Should -BeTrue
            $policy.AssignmentSignalsDisagree | Should -BeTrue
        }

        It 'reports no disagreement when both signals agree' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @(New-GraphAppProtectionPolicy) }

            (Get-MtAppProtectionPolicy -Platform iOS)[0].AssignmentSignalsDisagree | Should -BeFalse
        }

        It 'projects the Android encryption waiver as its own field' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @(New-GraphAppProtectionPolicy -OdataType '#microsoft.graph.androidManagedAppProtection' `
                        -EncryptAppData $true -DisableAppEncryptionIfDeviceEncryptionIsEnabled $true)
            }

            $policy = (Get-MtAppProtectionPolicy -Platform Android)[0]

            $policy.EncryptAppData | Should -BeTrue
            $policy.AppEncryptionDisabledByDeviceEncryption | Should -BeTrue
        }

        It 'shortens the odata type for the result tables' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @(New-GraphAppProtectionPolicy) }

            (Get-MtAppProtectionPolicy -Platform iOS)[0].PolicyType | Should -Be 'iosManagedAppProtection'
        }

        It 'rejects a platform it does not know' {
            { Get-MtAppProtectionPolicy -Platform Windows } | Should -Throw
        }
    }

    Context 'Test-MtIosAppProtectionPinPolicy (MT.TBD-21)' {
        It 'passes when an assigned policy meets every PIN requirement' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return @(Get-TestIosPolicy) }

            Test-MtIosAppProtectionPinPolicy | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'fails when no PIN is required, whatever the length says' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -PinRequired $false -MinimumPinLength 8)
            }

            Test-MtIosAppProtectionPinPolicy | Should -BeFalse
            $script:TestResult | Should -Match 'Not required'
        }

        It 'fails when simple PINs are allowed' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -SimplePinBlocked $false)
            }

            Test-MtIosAppProtectionPinPolicy | Should -BeFalse
        }

        It 'fails when the PIN is shorter than six characters' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -MinimumPinLength 4)
            }

            Test-MtIosAppProtectionPinPolicy | Should -BeFalse
        }

        It 'fails when the retry limit was never configured, instead of reading null as under the limit' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -MaximumPinRetries $null)
            }

            Test-MtIosAppProtectionPinPolicy | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'fails when the minimum PIN length was never configured' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -MinimumPinLength $null)
            }

            Test-MtIosAppProtectionPinPolicy | Should -BeFalse
        }

        It 'fails when the retry limit is zero, which bounds nothing' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -MaximumPinRetries 0)
            }

            Test-MtIosAppProtectionPinPolicy | Should -BeFalse
        }

        It 'fails when the retry limit is above five' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -MaximumPinRetries 10)
            }

            Test-MtIosAppProtectionPinPolicy | Should -BeFalse
        }

        It 'fails when the compliant policy is not assigned, and says so' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -AssignmentCount 0 -IsAssignedFlag $false)
            }

            Test-MtIosAppProtectionPinPolicy | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'does not let two policies combine into a pass' {
            # The point of evaluating the conjunction inside one test: a policy with the settings but
            # no assignment plus a policy assigned without the settings must not pass.
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(
                    (Get-TestIosPolicy -Name 'Configured, unassigned' -AssignmentCount 0 -IsAssignedFlag $false),
                    (Get-TestIosPolicy -Name 'Assigned, unconfigured' -PinRequired $false -MinimumPinLength 4)
                )
            }

            Test-MtIosAppProtectionPinPolicy | Should -BeFalse
        }

        It 'fails when the tenant has no iOS app protection policies' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { New-EmptyPolicyList }

            Test-MtIosAppProtectionPinPolicy | Should -BeFalse
            $script:TestResult | Should -Match 'No iOS app protection policies'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return $null }

            $null -eq (Test-MtIosAppProtectionPinPolicy) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }

        It 'notes the assigned policies that fall short even when another one passes' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(
                    (Get-TestIosPolicy -Name 'Strict'),
                    (Get-TestIosPolicy -Name 'Lenient' -MinimumPinLength 4 -AssignmentCount 2)
                )
            }

            Test-MtIosAppProtectionPinPolicy | Should -BeTrue
            $script:TestResult | Should -Match 'do not meet this requirement'
        }

        It 'notes a policy that waives the app PIN when the device has a passcode' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -DisableAppPinIfDevicePinIsSet $true)
            }

            Test-MtIosAppProtectionPinPolicy | Should -BeTrue
            $script:TestResult | Should -Match 'Recognize device PIN'
        }

        It 'notes a disagreement between the two assignment signals' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -AssignmentCount 0 -IsAssignedFlag $true)
            }

            Test-MtIosAppProtectionPinPolicy | Should -BeTrue
            $script:TestResult | Should -Match 'isAssigned property disagree'
        }
    }

    Context 'Test-MtIosAppProtectionDataTransfer (MT.TBD-22)' {
        It 'passes when an assigned policy closes every egress path' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return @(Get-TestIosPolicy) }

            Test-MtIosAppProtectionDataTransfer | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'passes when outbound transfer is blocked entirely' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -OutboundDataTransfer 'none' -ClipboardSharingLevel 'blocked')
            }

            Test-MtIosAppProtectionDataTransfer | Should -BeTrue
        }

        It 'fails when org data may be sent to all apps' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -OutboundDataTransfer 'allApps')
            }

            Test-MtIosAppProtectionDataTransfer | Should -BeFalse
            $script:TestResult | Should -Match 'allApps'
        }

        It 'fails when the clipboard may carry data to any app' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -ClipboardSharingLevel 'allApps')
            }

            Test-MtIosAppProtectionDataTransfer | Should -BeFalse
        }

        It 'fails when save-as is allowed' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -SaveAsBlocked $false)
            }

            Test-MtIosAppProtectionDataTransfer | Should -BeFalse
        }

        It 'fails when the app data backup is allowed' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -DataBackupBlocked $false)
            }

            Test-MtIosAppProtectionDataTransfer | Should -BeFalse
        }

        It 'fails when the setting is unset rather than permissive' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -OutboundDataTransfer $null -ClipboardSharingLevel $null)
            }

            Test-MtIosAppProtectionDataTransfer | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'fails when the compliant policy is not assigned, and says so' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -AssignmentCount 0 -IsAssignedFlag $false)
            }

            Test-MtIosAppProtectionDataTransfer | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'does not let two policies combine into a pass' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(
                    (Get-TestIosPolicy -Name 'Configured, unassigned' -AssignmentCount 0 -IsAssignedFlag $false),
                    (Get-TestIosPolicy -Name 'Assigned, open' -OutboundDataTransfer 'allApps' -SaveAsBlocked $false)
                )
            }

            Test-MtIosAppProtectionDataTransfer | Should -BeFalse
        }

        It 'fails when the tenant has no iOS app protection policies' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { New-EmptyPolicyList }

            Test-MtIosAppProtectionDataTransfer | Should -BeFalse
            $script:TestResult | Should -Match 'No iOS app protection policies'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return $null }

            $null -eq (Test-MtIosAppProtectionDataTransfer) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtIosAppProtectionEncryption (MT.TBD-23)' {
        It 'passes when an assigned policy encrypts org data' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return @(Get-TestIosPolicy) }

            Test-MtIosAppProtectionEncryption | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'passes for each encryption option other than the device default' -ForEach @(
            @{ Value = 'whenDeviceLocked' }
            @{ Value = 'whenDeviceLockedExceptOpenFiles' }
            @{ Value = 'afterDeviceRestart' }
        ) {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -AppDataEncryptionType $Value)
            }

            Test-MtIosAppProtectionEncryption | Should -BeTrue
        }

        It 'fails when encryption is deferred to the device settings' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -AppDataEncryptionType 'useDeviceSettings')
            }

            Test-MtIosAppProtectionEncryption | Should -BeFalse
            $script:TestResult | Should -Match 'useDeviceSettings'
        }

        It 'fails when the setting is absent' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -AppDataEncryptionType $null)
            }

            Test-MtIosAppProtectionEncryption | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'fails when the compliant policy is not assigned, and says so' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -AssignmentCount 0 -IsAssignedFlag $false)
            }

            Test-MtIosAppProtectionEncryption | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'fails when the tenant has no iOS app protection policies' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { New-EmptyPolicyList }

            Test-MtIosAppProtectionEncryption | Should -BeFalse
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return $null }

            $null -eq (Test-MtIosAppProtectionEncryption) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtIosAppProtectionMinimumVersions (MT.TBD-24)' {
        It 'passes when an assigned policy sets both floors' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return @(Get-TestIosPolicy) }

            Test-MtIosAppProtectionMinimumVersions | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'fails when the minimum OS version is absent' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -MinimumRequiredOsVersion $null)
            }

            Test-MtIosAppProtectionMinimumVersions | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'fails when the minimum OS version is an empty string' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -MinimumRequiredOsVersion '')
            }

            Test-MtIosAppProtectionMinimumVersions | Should -BeFalse
        }

        It 'fails when the minimum OS version is only whitespace' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -MinimumRequiredOsVersion '   ')
            }

            Test-MtIosAppProtectionMinimumVersions | Should -BeFalse
        }

        It 'fails when the minimum app version is absent' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -MinimumRequiredAppVersion $null)
            }

            Test-MtIosAppProtectionMinimumVersions | Should -BeFalse
        }

        It 'reports the SDK version without requiring it' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -MinimumRequiredSdkVersion '19.7.0')
            }

            Test-MtIosAppProtectionMinimumVersions | Should -BeTrue
            $script:TestResult | Should -Match '19\.7\.0'
        }

        It 'fails when the compliant policy is not assigned, and says so' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -AssignmentCount 0 -IsAssignedFlag $false)
            }

            Test-MtIosAppProtectionMinimumVersions | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'fails when the tenant has no iOS app protection policies' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { New-EmptyPolicyList }

            Test-MtIosAppProtectionMinimumVersions | Should -BeFalse
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return $null }

            $null -eq (Test-MtIosAppProtectionMinimumVersions) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtIosAppProtectionOfflineGracePeriod (MT.TBD-25)' {
        It 'passes when an assigned policy bounds both intervals' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return @(Get-TestIosPolicy) }

            Test-MtIosAppProtectionOfflineGracePeriod | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'fails when the grace period was never configured, instead of reading null as under the limit' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -OfflineBeforeAccessCheckHours $null)
            }

            Test-MtIosAppProtectionOfflineGracePeriod | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'fails when the wipe interval was never configured' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -OfflineBeforeWipeDays $null)
            }

            Test-MtIosAppProtectionOfflineGracePeriod | Should -BeFalse
        }

        It 'fails when the grace period is zero, which bounds nothing' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -OfflineBeforeAccessCheckHours 0)
            }

            Test-MtIosAppProtectionOfflineGracePeriod | Should -BeFalse
        }

        It 'fails when the grace period is longer than twelve hours' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -OfflineBeforeAccessCheckHours 48)
            }

            Test-MtIosAppProtectionOfflineGracePeriod | Should -BeFalse
        }

        It 'fails when the wipe interval is longer than ninety days' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -OfflineBeforeWipeDays 365)
            }

            Test-MtIosAppProtectionOfflineGracePeriod | Should -BeFalse
        }

        It 'passes for a stricter configuration' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -OfflineBeforeAccessCheckHours 2 -OfflineBeforeWipeDays 30)
            }

            Test-MtIosAppProtectionOfflineGracePeriod | Should -BeTrue
        }

        It 'fails when the compliant policy is not assigned, and says so' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -AssignmentCount 0 -IsAssignedFlag $false)
            }

            Test-MtIosAppProtectionOfflineGracePeriod | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'fails when the tenant has no iOS app protection policies' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { New-EmptyPolicyList }

            Test-MtIosAppProtectionOfflineGracePeriod | Should -BeFalse
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return $null }

            $null -eq (Test-MtIosAppProtectionOfflineGracePeriod) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtIosAppProtectionDeviceThreatLevel (MT.TBD-26)' {
        It 'passes when an assigned policy gates on the threat level and blocks' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return @(Get-TestIosPolicy) }

            Test-MtIosAppProtectionDeviceThreatLevel | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'passes for each level that is both configured and protective' -ForEach @(
            @{ Value = 'secured' }
            @{ Value = 'low' }
            @{ Value = 'medium' }
        ) {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -MaximumDeviceThreatLevel $Value)
            }

            Test-MtIosAppProtectionDeviceThreatLevel | Should -BeTrue
        }

        It 'fails when the threat level is not configured' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -MaximumDeviceThreatLevel 'notConfigured')
            }

            Test-MtIosAppProtectionDeviceThreatLevel | Should -BeFalse
        }

        It 'fails when the level admits every threat the partner reports' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -MaximumDeviceThreatLevel 'high')
            }

            Test-MtIosAppProtectionDeviceThreatLevel | Should -BeFalse
            $script:TestResult | Should -Match 'high'
        }

        It 'fails when the action only warns, although the level is strict' {
            # The flag and the level can contradict each other: a strict gate with a warning action
            # leaves the data on the device.
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -MaximumDeviceThreatLevel 'secured' -ThreatRemediationAction 'warn')
            }

            Test-MtIosAppProtectionDeviceThreatLevel | Should -BeFalse
            $script:TestResult | Should -Match 'warn'
        }

        It 'passes when the action wipes instead of blocking' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -ThreatRemediationAction 'wipe')
            }

            Test-MtIosAppProtectionDeviceThreatLevel | Should -BeTrue
        }

        It 'notes a permissive level even when another policy passes' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(
                    (Get-TestIosPolicy -Name 'Strict'),
                    (Get-TestIosPolicy -Name 'Permissive' -MaximumDeviceThreatLevel 'high' -AssignmentCount 3)
                )
            }

            Test-MtIosAppProtectionDeviceThreatLevel | Should -BeTrue
            $script:TestResult | Should -Match 'admits a device reported as high risk'
        }

        It 'fails when the compliant policy is not assigned, and says so' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestIosPolicy -AssignmentCount 0 -IsAssignedFlag $false)
            }

            Test-MtIosAppProtectionDeviceThreatLevel | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'fails when the tenant has no iOS app protection policies' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { New-EmptyPolicyList }

            Test-MtIosAppProtectionDeviceThreatLevel | Should -BeFalse
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return $null }

            $null -eq (Test-MtIosAppProtectionDeviceThreatLevel) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtAndroidAppProtectionPinPolicy (MT.TBD-27)' {
        It 'passes when an assigned policy meets every PIN requirement' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return @(Get-TestAndroidPolicy) }

            Test-MtAndroidAppProtectionPinPolicy | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'fails when no PIN is required, whatever the length says' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -PinRequired $false -MinimumPinLength 8)
            }

            Test-MtAndroidAppProtectionPinPolicy | Should -BeFalse
            $script:TestResult | Should -Match 'Not required'
        }

        It 'fails when simple PINs are allowed' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -SimplePinBlocked $false)
            }

            Test-MtAndroidAppProtectionPinPolicy | Should -BeFalse
        }

        It 'fails when the PIN is shorter than six characters' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -MinimumPinLength 4)
            }

            Test-MtAndroidAppProtectionPinPolicy | Should -BeFalse
        }

        It 'fails when the retry limit was never configured, instead of reading null as under the limit' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -MaximumPinRetries $null)
            }

            Test-MtAndroidAppProtectionPinPolicy | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'fails when the retry limit is zero, which bounds nothing' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -MaximumPinRetries 0)
            }

            Test-MtAndroidAppProtectionPinPolicy | Should -BeFalse
        }

        It 'fails when the compliant policy is not assigned, and says so' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -AssignmentCount 0 -IsAssignedFlag $false)
            }

            Test-MtAndroidAppProtectionPinPolicy | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'does not let two policies combine into a pass' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(
                    (Get-TestAndroidPolicy -Name 'Configured, unassigned' -AssignmentCount 0 -IsAssignedFlag $false),
                    (Get-TestAndroidPolicy -Name 'Assigned, unconfigured' -PinRequired $false -MinimumPinLength 4)
                )
            }

            Test-MtAndroidAppProtectionPinPolicy | Should -BeFalse
        }

        It 'fails when the tenant has no Android app protection policies' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { New-EmptyPolicyList }

            Test-MtAndroidAppProtectionPinPolicy | Should -BeFalse
            $script:TestResult | Should -Match 'No Android app protection policies'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return $null }

            $null -eq (Test-MtAndroidAppProtectionPinPolicy) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }

        It 'notes a policy that waives the app PIN when the device has a lock' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -DisableAppPinIfDevicePinIsSet $true)
            }

            Test-MtAndroidAppProtectionPinPolicy | Should -BeTrue
            $script:TestResult | Should -Match 'Recognize device PIN'
        }
    }

    Context 'Test-MtAndroidAppProtectionDataTransfer (MT.TBD-28)' {
        It 'passes when an assigned policy closes every egress path' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return @(Get-TestAndroidPolicy) }

            Test-MtAndroidAppProtectionDataTransfer | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'fails when org data may be sent to all apps' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -OutboundDataTransfer 'allApps')
            }

            Test-MtAndroidAppProtectionDataTransfer | Should -BeFalse
            $script:TestResult | Should -Match 'allApps'
        }

        It 'fails when the clipboard may carry data to any app' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -ClipboardSharingLevel 'allApps')
            }

            Test-MtAndroidAppProtectionDataTransfer | Should -BeFalse
        }

        It 'fails when save-as is allowed' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -SaveAsBlocked $false)
            }

            Test-MtAndroidAppProtectionDataTransfer | Should -BeFalse
        }

        It 'fails when the Android backup of org data is allowed' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -DataBackupBlocked $false)
            }

            Test-MtAndroidAppProtectionDataTransfer | Should -BeFalse
        }

        It 'fails when the setting is unset rather than permissive' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -OutboundDataTransfer $null -ClipboardSharingLevel $null)
            }

            Test-MtAndroidAppProtectionDataTransfer | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'fails when the compliant policy is not assigned, and says so' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -AssignmentCount 0 -IsAssignedFlag $false)
            }

            Test-MtAndroidAppProtectionDataTransfer | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'fails when the tenant has no Android app protection policies' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { New-EmptyPolicyList }

            Test-MtAndroidAppProtectionDataTransfer | Should -BeFalse
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return $null }

            $null -eq (Test-MtAndroidAppProtectionDataTransfer) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtAndroidAppProtectionEncryption (MT.TBD-29)' {
        It 'passes when an assigned policy requires encryption and does not waive it' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return @(Get-TestAndroidPolicy) }

            Test-MtAndroidAppProtectionEncryption | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'fails when encryption is not required' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -EncryptAppData $false)
            }

            Test-MtAndroidAppProtectionEncryption | Should -BeFalse
            $script:TestResult | Should -Match 'Not required'
        }

        It 'fails when encryption is required and waived on an encrypted device' {
            # The flag that contradicts the level: the portal shows encryption as required while the
            # waiver switches it off on any device that reports its own encryption.
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -EncryptAppData $true -AppEncryptionDisabledByDeviceEncryption $true)
            }

            Test-MtAndroidAppProtectionEncryption | Should -BeFalse
        }

        It 'notes the contradictory combination even when another policy passes' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(
                    (Get-TestAndroidPolicy -Name 'Strict'),
                    (Get-TestAndroidPolicy -Name 'Waived' -AppEncryptionDisabledByDeviceEncryption $true -AssignmentCount 4)
                )
            }

            Test-MtAndroidAppProtectionEncryption | Should -BeTrue
            $script:TestResult | Should -Match 'encrypt nothing on a device that reports device encryption'
        }

        It 'fails when the compliant policy is not assigned, and says so' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -AssignmentCount 0 -IsAssignedFlag $false)
            }

            Test-MtAndroidAppProtectionEncryption | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'fails when the tenant has no Android app protection policies' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { New-EmptyPolicyList }

            Test-MtAndroidAppProtectionEncryption | Should -BeFalse
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return $null }

            $null -eq (Test-MtAndroidAppProtectionEncryption) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtAndroidAppProtectionMinimumVersions (MT.TBD-30)' {
        It 'passes when an assigned policy sets both floors' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return @(Get-TestAndroidPolicy) }

            Test-MtAndroidAppProtectionMinimumVersions | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'fails when the minimum OS version is absent' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -MinimumRequiredOsVersion $null)
            }

            Test-MtAndroidAppProtectionMinimumVersions | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'fails when the minimum app version is absent' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -MinimumRequiredAppVersion '')
            }

            Test-MtAndroidAppProtectionMinimumVersions | Should -BeFalse
        }

        It 'reports the patch level without requiring it' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -MinimumRequiredPatchVersion '2025-06-01')
            }

            Test-MtAndroidAppProtectionMinimumVersions | Should -BeTrue
            $script:TestResult | Should -Match '2025-06-01'
        }

        It 'notes an assigned policy with no patch level floor' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -MinimumRequiredPatchVersion $null)
            }

            Test-MtAndroidAppProtectionMinimumVersions | Should -BeTrue
            $script:TestResult | Should -Match 'no minimum security patch'
        }

        It 'fails when the compliant policy is not assigned, and says so' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -AssignmentCount 0 -IsAssignedFlag $false)
            }

            Test-MtAndroidAppProtectionMinimumVersions | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'fails when the tenant has no Android app protection policies' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { New-EmptyPolicyList }

            Test-MtAndroidAppProtectionMinimumVersions | Should -BeFalse
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return $null }

            $null -eq (Test-MtAndroidAppProtectionMinimumVersions) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtAndroidAppProtectionOfflineGracePeriod (MT.TBD-31)' {
        It 'passes when an assigned policy bounds both intervals' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return @(Get-TestAndroidPolicy) }

            Test-MtAndroidAppProtectionOfflineGracePeriod | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'fails when the grace period was never configured, instead of reading null as under the limit' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -OfflineBeforeAccessCheckHours $null)
            }

            Test-MtAndroidAppProtectionOfflineGracePeriod | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'fails when the wipe interval was never configured' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -OfflineBeforeWipeDays $null)
            }

            Test-MtAndroidAppProtectionOfflineGracePeriod | Should -BeFalse
        }

        It 'fails when the grace period is zero, which bounds nothing' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -OfflineBeforeAccessCheckHours 0)
            }

            Test-MtAndroidAppProtectionOfflineGracePeriod | Should -BeFalse
        }

        It 'fails when the grace period is longer than twelve hours' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -OfflineBeforeAccessCheckHours 24)
            }

            Test-MtAndroidAppProtectionOfflineGracePeriod | Should -BeFalse
        }

        It 'fails when the wipe interval is longer than ninety days' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -OfflineBeforeWipeDays 180)
            }

            Test-MtAndroidAppProtectionOfflineGracePeriod | Should -BeFalse
        }

        It 'fails when the compliant policy is not assigned, and says so' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -AssignmentCount 0 -IsAssignedFlag $false)
            }

            Test-MtAndroidAppProtectionOfflineGracePeriod | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'fails when the tenant has no Android app protection policies' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { New-EmptyPolicyList }

            Test-MtAndroidAppProtectionOfflineGracePeriod | Should -BeFalse
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return $null }

            $null -eq (Test-MtAndroidAppProtectionOfflineGracePeriod) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtAndroidAppProtectionDeviceThreatLevel (MT.TBD-32)' {
        It 'passes when an assigned policy gates on the threat level and blocks' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return @(Get-TestAndroidPolicy) }

            Test-MtAndroidAppProtectionDeviceThreatLevel | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'fails when the threat level is not configured' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -MaximumDeviceThreatLevel 'notConfigured')
            }

            Test-MtAndroidAppProtectionDeviceThreatLevel | Should -BeFalse
        }

        It 'fails when the level admits every threat the partner reports' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -MaximumDeviceThreatLevel 'high')
            }

            Test-MtAndroidAppProtectionDeviceThreatLevel | Should -BeFalse
        }

        It 'fails when the action only warns, although the level is strict' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -MaximumDeviceThreatLevel 'secured' -ThreatRemediationAction 'warn')
            }

            Test-MtAndroidAppProtectionDeviceThreatLevel | Should -BeFalse
            $script:TestResult | Should -Match 'warn'
        }

        It 'notes a permissive level even when another policy passes' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(
                    (Get-TestAndroidPolicy -Name 'Strict'),
                    (Get-TestAndroidPolicy -Name 'Permissive' -MaximumDeviceThreatLevel 'high' -AssignmentCount 3)
                )
            }

            Test-MtAndroidAppProtectionDeviceThreatLevel | Should -BeTrue
            $script:TestResult | Should -Match 'admits a device reported as high risk'
        }

        It 'fails when the compliant policy is not assigned, and says so' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -AssignmentCount 0 -IsAssignedFlag $false)
            }

            Test-MtAndroidAppProtectionDeviceThreatLevel | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'fails when the tenant has no Android app protection policies' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { New-EmptyPolicyList }

            Test-MtAndroidAppProtectionDeviceThreatLevel | Should -BeFalse
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return $null }

            $null -eq (Test-MtAndroidAppProtectionDeviceThreatLevel) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtAndroidAppProtectionScreenCapture (MT.TBD-33)' {
        It 'passes when an assigned policy blocks screen capture' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return @(Get-TestAndroidPolicy) }

            Test-MtAndroidAppProtectionScreenCapture | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'fails when screen capture is allowed' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -ScreenCaptureBlocked $false)
            }

            Test-MtAndroidAppProtectionScreenCapture | Should -BeFalse
            $script:TestResult | Should -Match 'Allowed'
        }

        It 'fails when the compliant policy is not assigned, and says so' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -AssignmentCount 0 -IsAssignedFlag $false)
            }

            Test-MtAndroidAppProtectionScreenCapture | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'notes the assigned policies that allow it even when another one blocks it' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(
                    (Get-TestAndroidPolicy -Name 'Strict'),
                    (Get-TestAndroidPolicy -Name 'Open' -ScreenCaptureBlocked $false -AssignmentCount 2)
                )
            }

            Test-MtAndroidAppProtectionScreenCapture | Should -BeTrue
            $script:TestResult | Should -Match 'do not meet this requirement'
        }

        It 'fails when the tenant has no Android app protection policies' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { New-EmptyPolicyList }

            Test-MtAndroidAppProtectionScreenCapture | Should -BeFalse
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return $null }

            $null -eq (Test-MtAndroidAppProtectionScreenCapture) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtAndroidAppProtectionDeviceAttestation (MT.TBD-34)' {
        It 'passes when an assigned policy requires attestation and blocks on failure' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return @(Get-TestAndroidPolicy) }

            Test-MtAndroidAppProtectionDeviceAttestation | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'passes with basic integrity alone' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -DeviceAttestationType 'basicIntegrity')
            }

            Test-MtAndroidAppProtectionDeviceAttestation | Should -BeTrue
        }

        It 'fails when attestation is not required' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -DeviceAttestationType 'none')
            }

            Test-MtAndroidAppProtectionDeviceAttestation | Should -BeFalse
            $script:TestResult | Should -Match 'none'
        }

        It 'fails when attestation is required but the action only warns' {
            # The gate and the action can contradict each other: the check runs, the user is told, and
            # the organization data stays on a device Google will not vouch for.
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -ActionIfAttestationFailed 'warn')
            }

            Test-MtAndroidAppProtectionDeviceAttestation | Should -BeFalse
            $script:TestResult | Should -Match 'warn'
        }

        It 'fails when the action is absent' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -ActionIfAttestationFailed $null)
            }

            Test-MtAndroidAppProtectionDeviceAttestation | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'passes when the action wipes instead of blocking' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -ActionIfAttestationFailed 'wipe')
            }

            Test-MtAndroidAppProtectionDeviceAttestation | Should -BeTrue
        }

        It 'notes a warn-only policy even when another one blocks' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(
                    (Get-TestAndroidPolicy -Name 'Strict'),
                    (Get-TestAndroidPolicy -Name 'Warn only' -ActionIfAttestationFailed 'warn' -AssignmentCount 2)
                )
            }

            Test-MtAndroidAppProtectionDeviceAttestation | Should -BeTrue
            $script:TestResult | Should -Match 'do not block'
        }

        It 'fails when the compliant policy is not assigned, and says so' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(Get-TestAndroidPolicy -AssignmentCount 0 -IsAssignedFlag $false)
            }

            Test-MtAndroidAppProtectionDeviceAttestation | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'does not let two policies combine into a pass' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy {
                return @(
                    (Get-TestAndroidPolicy -Name 'Configured, unassigned' -AssignmentCount 0 -IsAssignedFlag $false),
                    (Get-TestAndroidPolicy -Name 'Assigned, no attestation' -DeviceAttestationType 'none')
                )
            }

            Test-MtAndroidAppProtectionDeviceAttestation | Should -BeFalse
        }

        It 'fails when the tenant has no Android app protection policies' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { New-EmptyPolicyList }

            Test-MtAndroidAppProtectionDeviceAttestation | Should -BeFalse
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtAppProtectionPolicy { return $null }

            $null -eq (Test-MtAndroidAppProtectionDeviceAttestation) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }
}
