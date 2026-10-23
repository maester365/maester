Describe 'iOS and Android Intune compliance checks' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # Check functions that became native tests are not exported.
        Use-MtModuleFunction -Name Test-MtIosJailbrokenDevices, Test-MtIosPasscodePolicy, Test-MtIosMinimumOsVersion,
        Test-MtIosDefenderRiskScore, Test-MtAndroidRootedDevices, Test-MtAndroidPasswordPolicy,
        Test-MtAndroidSecurityPatchLevel, Test-MtAndroidThreatProtection, Test-MtAndroidUsbDebugging,
        Test-MtAndroidDeviceAdministratorBlocked

        function Get-TestIosPolicy {
            param(
                [string] $Name = 'iOS Compliance',
                [int] $AssignmentCount = 1,
                [bool] $BlocksJailbrokenDevices = $true,
                [bool] $PasscodeRequired = $true,
                [bool] $PasscodeBlocksSimple = $true,
                $PasscodeMinimumLength = 6,
                $PasscodeInactivityMinutes = 15,
                [string] $MinimumOsVersion = '18.0',
                [bool] $RequiresThreatProtection = $true,
                [string] $DefenderRiskScoreLevel = 'medium'
            )

            return [pscustomobject]@{
                Id                        = [guid]::NewGuid().ToString()
                Name                      = $Name
                Platform                  = 'iOS'
                PolicyType                = 'iosCompliancePolicy'
                SettingsEvaluated         = $true
                AssignmentCount           = $AssignmentCount
                IsAssigned                = ($AssignmentCount -gt 0)
                BlocksJailbrokenDevices   = $BlocksJailbrokenDevices
                PasscodeRequired          = $PasscodeRequired
                PasscodeBlocksSimple      = $PasscodeBlocksSimple
                PasscodeMinimumLength     = $PasscodeMinimumLength
                PasscodeInactivityMinutes = $PasscodeInactivityMinutes
                MinimumOsVersion          = $MinimumOsVersion
                RequiresThreatProtection  = $RequiresThreatProtection
                DefenderRiskScoreLevel    = $DefenderRiskScoreLevel
            }
        }

        function Get-TestAndroidPolicy {
            param(
                [string] $Name = 'Android Compliance',
                [int] $AssignmentCount = 1,
                [bool] $BlocksRootedDevices = $true,
                [bool] $BlocksDeviceAdministrator = $true,
                [bool] $UsbDebuggingDisabled = $true,
                $MinimumSecurityPatchLevel = ([datetime]::UtcNow.AddDays(-30).ToString('yyyy-MM-dd')),
                [bool] $PasswordRequired = $true,
                $ComplexityValue = 'high',
                $MinimumLength = 6,
                $InactivityMinutes = 15,
                [bool] $RequiresThreatProtection = $true
            )

            return [pscustomobject]@{
                Id                        = [guid]::NewGuid().ToString()
                Name                      = $Name
                Platform                  = 'Android'
                PolicyType                = 'androidCompliancePolicy'
                SettingsEvaluated         = $true
                AssignmentCount           = $AssignmentCount
                IsAssigned                = ($AssignmentCount -gt 0)
                BlocksRootedDevices       = $BlocksRootedDevices
                BlocksDeviceAdministrator = $BlocksDeviceAdministrator
                UsbDebuggingDisabled      = $UsbDebuggingDisabled
                MinimumSecurityPatchLevel = $MinimumSecurityPatchLevel
                PasswordRequired          = $PasswordRequired
                PasswordComplexity        = $ComplexityValue
                PasswordMinimumLength     = $MinimumLength
                PasswordInactivityMinutes = $InactivityMinutes
                RequiresThreatProtection  = $RequiresThreatProtection
            }
        }

        function Get-TestAndroidEnterprisePolicy {
            # An Android Enterprise policy as the helper returns it: reported, never evaluated, with
            # every setting left null rather than guessed from unverified property names.
            param(
                [string] $Name = 'Android Work Profile',
                [int] $AssignmentCount = 1,
                [string] $PolicyType = 'androidWorkProfileCompliancePolicy'
            )

            return [pscustomobject]@{
                Id                        = [guid]::NewGuid().ToString()
                Name                      = $Name
                Platform                  = 'Android'
                PolicyType                = $PolicyType
                SettingsEvaluated         = $false
                AssignmentCount           = $AssignmentCount
                IsAssigned                = ($AssignmentCount -gt 0)
                BlocksRootedDevices       = $false
                BlocksDeviceAdministrator = $false
                UsbDebuggingDisabled      = $false
                MinimumSecurityPatchLevel = $null
                PasswordRequired          = $false
                PasswordComplexity        = $null
                PasswordMinimumLength     = $null
                PasswordInactivityMinutes = $null
                RequiresThreatProtection  = $false
            }
        }

        function New-EmptyPolicyList {
            # Mirror the real helper: emit an empty list without unrolling it to $null.
            Write-Output ([System.Collections.Generic.List[pscustomobject]]::new()) -NoEnumerate
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

    Context 'Test-MtIosJailbrokenDevices (MT.1228)' {
        It 'passes when an assigned policy blocks jailbroken devices' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -BlocksJailbrokenDevices $true -AssignmentCount 1)
            }

            Test-MtIosJailbrokenDevices | Should -BeTrue
            $script:TestResult | Should -Match 'Blocked'
        }

        It 'fails when no policy blocks jailbroken devices' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -BlocksJailbrokenDevices $false)
            }

            Test-MtIosJailbrokenDevices | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'fails when the only policy blocking jailbroken devices is unassigned, and says so' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -BlocksJailbrokenDevices $true -AssignmentCount 0)
            }

            Test-MtIosJailbrokenDevices | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'fails when the tenant has no iOS compliance policies' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { New-EmptyPolicyList }

            Test-MtIosJailbrokenDevices | Should -BeFalse
            $script:TestResult | Should -Match 'No iOS compliance policies'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { return $null }

            $null -eq (Test-MtIosJailbrokenDevices) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }

        It 'notes assigned policies that do not block jailbroken devices even when passing' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(
                    (Get-TestIosPolicy -Name 'Strict' -BlocksJailbrokenDevices $true),
                    (Get-TestIosPolicy -Name 'Lenient' -BlocksJailbrokenDevices $false -AssignmentCount 2)
                )
            }

            Test-MtIosJailbrokenDevices | Should -BeTrue
            $script:TestResult | Should -Match 'do not block jailbroken devices'
        }
    }

    Context 'Test-MtIosPasscodePolicy (MT.1229)' {
        It 'passes when an assigned policy meets every passcode requirement' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { return @(Get-TestIosPolicy) }

            Test-MtIosPasscodePolicy | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'fails when no passcode is required' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -PasscodeRequired $false)
            }

            Test-MtIosPasscodePolicy | Should -BeFalse
        }

        It 'fails when simple passcodes are allowed' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -PasscodeBlocksSimple $false)
            }

            Test-MtIosPasscodePolicy | Should -BeFalse
            $script:TestResult | Should -Match 'Allowed'
        }

        It 'fails when the minimum length is below the required one' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -PasscodeMinimumLength 4)
            }

            Test-MtIosPasscodePolicy | Should -BeFalse
        }

        It 'fails when the inactivity lock is not configured' {
            # The trap this guards: $null -le 15 is true in PowerShell, so a missing value would
            # otherwise read as "under the limit" and report the weakest configuration as a pass.
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -PasscodeInactivityMinutes $null)
            }

            Test-MtIosPasscodePolicy | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'fails when the inactivity lock is longer than allowed' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -PasscodeInactivityMinutes 60)
            }

            Test-MtIosPasscodePolicy | Should -BeFalse
        }

        It 'does not count requirements met across two different policies' {
            # A device is evaluated against each policy as a whole, so one policy with the length and
            # another with the lock timeout leaves no policy that enforces both.
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(
                    (Get-TestIosPolicy -Name 'Length only' -PasscodeMinimumLength 8 -PasscodeInactivityMinutes $null),
                    (Get-TestIosPolicy -Name 'Lock only' -PasscodeMinimumLength 4 -PasscodeInactivityMinutes 5)
                )
            }

            Test-MtIosPasscodePolicy | Should -BeFalse
        }

        It 'honours stricter thresholds passed as parameters' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -PasscodeMinimumLength 6 -PasscodeInactivityMinutes 15)
            }

            Test-MtIosPasscodePolicy -MinimumPasscodeLength 8 -MaximumInactivityMinutes 5 | Should -BeFalse
            $script:TestResult | Should -Match 'at least 8 characters'
        }

        It 'does not count a compliant but unassigned policy' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -AssignmentCount 0)
            }

            Test-MtIosPasscodePolicy | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'notes the assigned policies that fall short even when passing' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(
                    (Get-TestIosPolicy -Name 'Strict'),
                    (Get-TestIosPolicy -Name 'Lenient' -PasscodeBlocksSimple $false -AssignmentCount 2)
                )
            }

            Test-MtIosPasscodePolicy | Should -BeTrue
            $script:TestResult | Should -Match 'do not meet every passcode requirement'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { return $null }

            $null -eq (Test-MtIosPasscodePolicy) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtIosMinimumOsVersion (MT.1230)' {
        It 'passes when any minimum version is set' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -MinimumOsVersion '17.5')
            }

            Test-MtIosMinimumOsVersion | Should -BeTrue
            $script:TestResult | Should -Match 'any minimum version'
        }

        It 'fails when no minimum version is set' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -MinimumOsVersion '')
            }

            Test-MtIosMinimumOsVersion | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'passes when the version meets the required one' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -MinimumOsVersion '18.1')
            }

            Test-MtIosMinimumOsVersion -MinimumOsVersion '18.0' | Should -BeTrue
        }

        It 'fails when the version is below the required one' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -MinimumOsVersion '17.0')
            }

            Test-MtIosMinimumOsVersion -MinimumOsVersion '18.0' | Should -BeFalse
            $script:TestResult | Should -Match 'iOS 18.0 or later'
        }

        It 'reads a single part version as a major version rather than as unusable' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -MinimumOsVersion '18')
            }

            Test-MtIosMinimumOsVersion -MinimumOsVersion '18' | Should -BeTrue
            $script:TestResult | Should -Not -Match 'cannot be compared'
        }

        It 'does not accept a version it cannot compare, and says so' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -MinimumOsVersion 'latest')
            }

            Test-MtIosMinimumOsVersion -MinimumOsVersion '18.0' | Should -BeFalse
            $script:TestResult | Should -Match 'cannot be compared'
        }

        It 'does not count a policy that is not assigned' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -MinimumOsVersion '18.0' -AssignmentCount 0)
            }

            Test-MtIosMinimumOsVersion | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'fails when the tenant has no iOS compliance policies' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { New-EmptyPolicyList }

            Test-MtIosMinimumOsVersion | Should -BeFalse
            $script:TestResult | Should -Match 'No iOS compliance policies'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { return $null }

            $null -eq (Test-MtIosMinimumOsVersion) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtIosDefenderRiskScore (MT.1231)' {
        It 'passes for a configured threshold' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -DefenderRiskScoreLevel 'medium')
            }

            Test-MtIosDefenderRiskScore | Should -BeTrue
        }

        It 'passes for the strictest secured level' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -DefenderRiskScoreLevel 'secured')
            }

            Test-MtIosDefenderRiskScore | Should -BeTrue
        }

        It 'fails for unavailable, which means the level is not evaluated' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -DefenderRiskScoreLevel 'unavailable')
            }

            Test-MtIosDefenderRiskScore | Should -BeFalse
            $script:TestResult | Should -Match 'Not evaluated'
        }

        It 'fails for notSet' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -DefenderRiskScoreLevel 'notSet')
            }

            Test-MtIosDefenderRiskScore | Should -BeFalse
        }

        It 'does not mislabel an unrecognised risk level as Not evaluated' {
            # Graph enums gain values over time; a real but unknown value must be shown as returned.
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -DefenderRiskScoreLevel 'someFutureLevel')
            }

            Test-MtIosDefenderRiskScore | Should -BeFalse
            $script:TestResult | Should -Not -Match 'Not evaluated'
            $script:TestResult | Should -Match 'someFutureLevel'
        }

        It 'notes when a threshold is set without device threat protection' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -DefenderRiskScoreLevel 'medium' -RequiresThreatProtection $false)
            }

            Test-MtIosDefenderRiskScore | Should -BeTrue
            $script:TestResult | Should -Match 'onboarded to Microsoft Defender for Endpoint'
        }

        It 'does not count a configured but unassigned policy' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -DefenderRiskScoreLevel 'medium' -AssignmentCount 0)
            }

            Test-MtIosDefenderRiskScore | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { return $null }

            $null -eq (Test-MtIosDefenderRiskScore) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtAndroidRootedDevices (MT.1232)' {
        It 'passes when an assigned policy blocks rooted devices' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -BlocksRootedDevices $true)
            }

            Test-MtAndroidRootedDevices | Should -BeTrue
            $script:TestResult | Should -Match 'Blocked'
        }

        It 'fails when no policy blocks rooted devices' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -BlocksRootedDevices $false)
            }

            Test-MtAndroidRootedDevices | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'does not count a blocking but unassigned policy' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -BlocksRootedDevices $true -AssignmentCount 0)
            }

            Test-MtAndroidRootedDevices | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'fails when the tenant has no Android compliance policy of any kind' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { New-EmptyPolicyList }

            Test-MtAndroidRootedDevices | Should -BeFalse
            $script:TestResult | Should -Match 'No Android compliance policies'
        }

        It 'reports NotApplicable when the tenant only uses Android Enterprise' {
            # The setting is read from the device administrator policy type. Having none of those is
            # the modern posture, so reporting a failure would be a false finding.
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidEnterprisePolicy)
            }

            $null -eq (Test-MtAndroidRootedDevices) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotApplicable'
        }

        It 'reports the Android Enterprise policies it did not evaluate' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(
                    (Get-TestAndroidPolicy -Name 'Legacy DA'),
                    (Get-TestAndroidEnterprisePolicy -Name 'Work profile'),
                    (Get-TestAndroidEnterprisePolicy -Name 'Fully managed' -PolicyType 'androidDeviceOwnerCompliancePolicy')
                )
            }

            Test-MtAndroidRootedDevices | Should -BeTrue
            $script:TestResult | Should -Match 'Found 1 Android device administrator compliance policy'
            $script:TestResult | Should -Match '2 Android Enterprise compliance policy/policies'
            # Counted in the note, never given a row of its own: no setting of it was read.
            $script:TestResult | Should -Match '\| Legacy DA \|'
            $script:TestResult | Should -Not -Match '\| Work profile \|'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { return $null }

            $null -eq (Test-MtAndroidRootedDevices) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtAndroidPasswordPolicy (MT.1233)' {
        It 'passes when an assigned policy meets every password requirement' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { return @(Get-TestAndroidPolicy) }

            Test-MtAndroidPasswordPolicy | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'fails when no password is required' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -PasswordRequired $false)
            }

            Test-MtAndroidPasswordPolicy | Should -BeFalse
        }

        It 'fails when the inactivity lock is not configured' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -InactivityMinutes $null)
            }

            Test-MtAndroidPasswordPolicy | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'does not count requirements met across two different policies' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(
                    (Get-TestAndroidPolicy -Name 'Length only' -MinimumLength 8 -InactivityMinutes $null),
                    (Get-TestAndroidPolicy -Name 'Lock only' -MinimumLength 4 -InactivityMinutes 5)
                )
            }

            Test-MtAndroidPasswordPolicy | Should -BeFalse
        }

        It 'reports an unrecognised complexity value as returned without changing the verdict' {
            # The values this property accepts are not verified, so the check reports it and does not
            # gate on it. A policy that meets the other requirements still passes.
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -ComplexityValue 'someFutureComplexity')
            }

            Test-MtAndroidPasswordPolicy | Should -BeTrue
            $script:TestResult | Should -Match 'someFutureComplexity'
        }

        It 'reports a missing complexity value as not reported' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -ComplexityValue $null)
            }

            Test-MtAndroidPasswordPolicy | Should -BeTrue
            $script:TestResult | Should -Match 'Not reported'
        }

        It 'honours stricter thresholds passed as parameters' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { return @(Get-TestAndroidPolicy) }

            Test-MtAndroidPasswordPolicy -MinimumPasswordLength 8 | Should -BeFalse
            $script:TestResult | Should -Match 'at least 8 characters'
        }

        It 'notes the assigned policies that fall short even when passing' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(
                    (Get-TestAndroidPolicy -Name 'Strict'),
                    (Get-TestAndroidPolicy -Name 'Lenient' -MinimumLength 4 -AssignmentCount 2)
                )
            }

            Test-MtAndroidPasswordPolicy | Should -BeTrue
            $script:TestResult | Should -Match 'do not meet every password requirement'
        }

        It 'reports NotApplicable when the tenant only uses Android Enterprise' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidEnterprisePolicy)
            }

            $null -eq (Test-MtAndroidPasswordPolicy) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotApplicable'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { return $null }

            $null -eq (Test-MtAndroidPasswordPolicy) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtAndroidSecurityPatchLevel (MT.1234)' {
        It 'passes for a recent patch level' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -MinimumSecurityPatchLevel ([datetime]::UtcNow.AddDays(-60).ToString('yyyy-MM-dd')))
            }

            Test-MtAndroidSecurityPatchLevel | Should -BeTrue
        }

        It 'fails when the patch level is older than the accepted age' {
            # A policy that requires patches from years ago accepts every device while looking
            # configured in the portal.
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -MinimumSecurityPatchLevel '2019-01-01')
            }

            Test-MtAndroidSecurityPatchLevel | Should -BeFalse
            $script:TestResult | Should -Match 'too old'
            $script:TestResult | Should -Match 'Move the date forward'
        }

        It 'accepts an older patch level when the allowed age is widened' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -MinimumSecurityPatchLevel ([datetime]::UtcNow.AddDays(-400).ToString('yyyy-MM-dd')))
            }

            Test-MtAndroidSecurityPatchLevel | Should -BeFalse
            Test-MtAndroidSecurityPatchLevel -MaximumPatchLevelAgeInDays 500 | Should -BeTrue
        }

        It 'fails when no patch level is configured' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -MinimumSecurityPatchLevel '')
            }

            Test-MtAndroidSecurityPatchLevel | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'does not accept a value that is not a date, and says so' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -MinimumSecurityPatchLevel 'latest')
            }

            Test-MtAndroidSecurityPatchLevel | Should -BeFalse
            $script:TestResult | Should -Match 'not a date'
            # And the summary must not claim no policy requires a patch level: one does, unreadably.
            $script:TestResult | Should -Not -Match 'No assigned Android compliance policy requires a minimum security patch level'
            $script:TestResult | Should -Match 'could not be read as a date'
        }

        It 'does not count a recent but unassigned policy' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -AssignmentCount 0)
            }

            Test-MtAndroidSecurityPatchLevel | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'reports NotApplicable when the tenant only uses Android Enterprise' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidEnterprisePolicy)
            }

            $null -eq (Test-MtAndroidSecurityPatchLevel) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotApplicable'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { return $null }

            $null -eq (Test-MtAndroidSecurityPatchLevel) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtAndroidThreatProtection (MT.1235)' {
        It 'passes when an assigned policy requires device threat protection' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -RequiresThreatProtection $true)
            }

            Test-MtAndroidThreatProtection | Should -BeTrue
            $script:TestResult | Should -Match 'MT.1098'
        }

        It 'fails when no policy requires device threat protection' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -RequiresThreatProtection $false)
            }

            Test-MtAndroidThreatProtection | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'does not count a requiring but unassigned policy' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -AssignmentCount 0)
            }

            Test-MtAndroidThreatProtection | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'reports NotApplicable when the tenant only uses Android Enterprise' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidEnterprisePolicy)
            }

            $null -eq (Test-MtAndroidThreatProtection) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotApplicable'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { return $null }

            $null -eq (Test-MtAndroidThreatProtection) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtAndroidUsbDebugging (MT.1236)' {
        It 'passes when an assigned policy blocks USB debugging' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -UsbDebuggingDisabled $true)
            }

            Test-MtAndroidUsbDebugging | Should -BeTrue
            $script:TestResult | Should -Match 'Blocked'
        }

        It 'fails when USB debugging is not blocked' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -UsbDebuggingDisabled $false)
            }

            Test-MtAndroidUsbDebugging | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'does not count a blocking but unassigned policy' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -AssignmentCount 0)
            }

            Test-MtAndroidUsbDebugging | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'reports NotApplicable when the tenant only uses Android Enterprise' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidEnterprisePolicy)
            }

            $null -eq (Test-MtAndroidUsbDebugging) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotApplicable'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { return $null }

            $null -eq (Test-MtAndroidUsbDebugging) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtAndroidDeviceAdministratorBlocked (MT.1237)' {
        It 'passes when an assigned policy blocks device administrator managed devices' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -BlocksDeviceAdministrator $true)
            }

            Test-MtAndroidDeviceAdministratorBlocked | Should -BeTrue
            $script:TestResult | Should -Match 'Blocked'
        }

        It 'fails when device administrator enrollments are still accepted' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -BlocksDeviceAdministrator $false)
            }

            Test-MtAndroidDeviceAdministratorBlocked | Should -BeFalse
            $script:TestResult | Should -Match 'no longer enforced by Android'
        }

        It 'does not count a blocking but unassigned policy' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidPolicy -AssignmentCount 0)
            }

            Test-MtAndroidDeviceAdministratorBlocked | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'reports NotApplicable when the tenant has no device administrator policy' {
            # Unlike the other Android checks this one is about the legacy policy type itself, so a
            # tenant with none of them has nothing to configure, whether or not it uses Enterprise.
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestAndroidEnterprisePolicy)
            }

            $null -eq (Test-MtAndroidDeviceAdministratorBlocked) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotApplicable'
        }

        It 'reports NotApplicable when the tenant has no Android compliance policy at all' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { New-EmptyPolicyList }

            $null -eq (Test-MtAndroidDeviceAdministratorBlocked) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotApplicable'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy { return $null }

            $null -eq (Test-MtAndroidDeviceAdministratorBlocked) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Edge cases and unexpected data' {
        It 'handles a policy with an empty display name without throwing' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -Name '')
            }

            { Test-MtIosJailbrokenDevices } | Should -Not -Throw
        }

        It 'handles many iOS policies with mixed states' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(
                    (Get-TestIosPolicy -Name 'A' -BlocksJailbrokenDevices $true -AssignmentCount 1),
                    (Get-TestIosPolicy -Name 'B' -BlocksJailbrokenDevices $false -AssignmentCount 3),
                    (Get-TestIosPolicy -Name 'C' -BlocksJailbrokenDevices $true -AssignmentCount 0),
                    (Get-TestIosPolicy -Name 'D' -BlocksJailbrokenDevices $false -AssignmentCount 0)
                )
            }

            Test-MtIosJailbrokenDevices | Should -BeTrue
            $script:TestResult | Should -Match 'Found 4 iOS compliance'
        }

        It 'reports a zero minimum passcode length as not configured rather than as zero' {
            Mock -ModuleName Maester Get-MtMobileCompliancePolicy {
                return @(Get-TestIosPolicy -PasscodeMinimumLength 0)
            }

            Test-MtIosPasscodePolicy | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }
    }

    Context 'Get-MtMobileCompliancePolicy' {
        It 'returns only iOS policies for -Platform iOS and carries assignment state' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @(
                    [pscustomobject]@{
                        id                             = 'ios-1'
                        '@odata.type'                  = '#microsoft.graph.iosCompliancePolicy'
                        displayName                    = 'iOS Compliance'
                        securityBlockJailbrokenDevices = $true
                        passcodeRequired               = $true
                        passcodeBlockSimple            = $true
                        passcodeMinimumLength          = 6
                        osMinimumVersion               = '18.0'
                        assignments                    = @([pscustomobject]@{ id = 'a1' })
                    },
                    [pscustomobject]@{
                        id            = 'droid-1'
                        '@odata.type' = '#microsoft.graph.androidCompliancePolicy'
                        displayName   = 'Android Compliance'
                        assignments   = @()
                    },
                    [pscustomobject]@{
                        id            = 'mac-1'
                        '@odata.type' = '#microsoft.graph.macOSCompliancePolicy'
                        displayName   = 'Mac Compliance'
                        assignments   = @()
                    }
                )
            }

            InModuleScope Maester {
                $result = Get-MtMobileCompliancePolicy -Platform iOS
                $null -ne $result | Should -BeTrue
                $result.Count | Should -Be 1
                $result[0].Name | Should -Be 'iOS Compliance'
                $result[0].BlocksJailbrokenDevices | Should -BeTrue
                $result[0].PasscodeMinimumLength | Should -Be 6
                $result[0].MinimumOsVersion | Should -Be '18.0'
                $result[0].IsAssigned | Should -BeTrue
                $result[0].AssignmentCount | Should -Be 1
                $result[0].SettingsEvaluated | Should -BeTrue
            }
        }

        It 'returns the Android device administrator policy with its settings read' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @(
                    [pscustomobject]@{
                        id                                            = 'droid-1'
                        '@odata.type'                                 = '#microsoft.graph.androidCompliancePolicy'
                        displayName                                   = 'Android DA'
                        securityBlockJailbrokenDevices                = $true
                        securityBlockDeviceAdministratorManagedDevices = $true
                        securityDisableUsbDebugging                   = $true
                        minAndroidSecurityPatchLevel                  = '2026-06-01'
                        passwordRequired                              = $true
                        requiredPasswordComplexity                    = 'high'
                        passwordMinimumLength                         = 6
                        passwordMinutesOfInactivityBeforeLock         = 15
                        deviceThreatProtectionEnabled                 = $true
                        assignments                                   = @([pscustomobject]@{ id = 'a1' }, [pscustomobject]@{ id = 'a2' })
                    }
                )
            }

            InModuleScope Maester {
                $result = Get-MtMobileCompliancePolicy -Platform Android
                $result.Count | Should -Be 1
                $result[0].PolicyType | Should -Be 'androidCompliancePolicy'
                $result[0].SettingsEvaluated | Should -BeTrue
                $result[0].BlocksRootedDevices | Should -BeTrue
                $result[0].BlocksDeviceAdministrator | Should -BeTrue
                $result[0].UsbDebuggingDisabled | Should -BeTrue
                $result[0].MinimumSecurityPatchLevel | Should -Be '2026-06-01'
                $result[0].PasswordComplexity | Should -Be 'high'
                $result[0].PasswordInactivityMinutes | Should -Be 15
                $result[0].AssignmentCount | Should -Be 2
            }
        }

        It 'returns Android Enterprise policies as reported but not evaluated, with no guessed settings' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @(
                    [pscustomobject]@{
                        id            = 'wp-1'
                        '@odata.type' = '#microsoft.graph.androidWorkProfileCompliancePolicy'
                        displayName   = 'Work profile'
                        # Present on the real object, deliberately not read by this helper.
                        passwordMinimumLength = 4
                        assignments   = @([pscustomobject]@{ id = 'a1' })
                    },
                    [pscustomobject]@{
                        id            = 'do-1'
                        '@odata.type' = '#microsoft.graph.androidDeviceOwnerCompliancePolicy'
                        displayName   = 'Fully managed'
                        assignments   = @()
                    }
                )
            }

            InModuleScope Maester {
                $result = Get-MtMobileCompliancePolicy -Platform Android
                $result.Count | Should -Be 2
                @($result | Where-Object { $_.SettingsEvaluated }).Count | Should -Be 0
                $result[0].PolicyType | Should -Be 'androidWorkProfileCompliancePolicy'
                # Not read, so not reported: a value taken from an unverified property name would be a guess.
                $null -eq $result[0].PasswordMinimumLength | Should -BeTrue
                $result[0].IsAssigned | Should -BeTrue
                $result[1].IsAssigned | Should -BeFalse
            }
        }

        It 'returns null when the request yields elements without an id' {
            # A failed Graph call surfaces as a non-terminating error with a null result, which collects
            # as a single empty element. That must not look like an empty tenant.
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @($null) }

            InModuleScope Maester {
                $null -eq (Get-MtMobileCompliancePolicy -Platform iOS) | Should -BeTrue
                $null -eq (Get-MtMobileCompliancePolicy -Platform Android) | Should -BeTrue
            }
        }

        It 'returns an empty list when the tenant genuinely has no policies' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

            InModuleScope Maester {
                $result = Get-MtMobileCompliancePolicy -Platform iOS
                # Must be an empty collection, NOT $null - $null means "could not read".
                $null -ne $result | Should -BeTrue
                $result.Count | Should -Be 0
            }
        }

        It 'returns an empty list when the tenant has policies but none for the platform' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @([pscustomobject]@{
                        id            = 'win-1'
                        '@odata.type' = '#microsoft.graph.windows10CompliancePolicy'
                        displayName   = 'Windows Compliance'
                        assignments   = @()
                    })
            }

            InModuleScope Maester {
                $result = Get-MtMobileCompliancePolicy -Platform Android
                $null -ne $result | Should -BeTrue
                $result.Count | Should -Be 0
            }
        }
    }

    Context 'Companion markdown' {
        It 'documents the Android scope limitation in every Android guide' {
            # Static explanation belongs in the description, not repeated in every result.
            foreach ($id in @('MT.1232', 'MT.1233', 'MT.1234', 'MT.1235', 'MT.1236', 'MT.1237')) {
                $md = Get-Content (Get-MtTest -Id $id).MarkdownPath -Raw
                $md | Should -Match '(?i)Scope limitation'
                $md | Should -Match 'device administrator'
            }
        }

        It 'states in the iOS and Android guides that an unassigned policy is never evaluated' {
            foreach ($id in @('MT.1228', 'MT.1229', 'MT.1232', 'MT.1233')) {
                $md = Get-Content (Get-MtTest -Id $id).MarkdownPath -Raw
                $md | Should -Match 'not assigned'
            }
        }
    }
}
