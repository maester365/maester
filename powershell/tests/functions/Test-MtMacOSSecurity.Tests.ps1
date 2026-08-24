Describe 'macOS Intune security checks' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force

        function Get-TestCompliancePolicy {
            param(
                [string] $Name = 'Mac Compliance',
                [int] $AssignmentCount = 1,
                [bool] $RequiresSip = $true,
                [string] $GatekeeperAllowedSource = 'macAppStoreAndIdentifiedDevelopers',
                [string] $DefenderRiskScoreLevel = 'medium',
                [bool] $RequiresThreatProtection = $true
            )

            return [pscustomobject]@{
                Id                       = [guid]::NewGuid().ToString()
                Name                     = $Name
                AssignmentCount          = $AssignmentCount
                IsAssigned               = ($AssignmentCount -gt 0)
                RequiresSip              = $RequiresSip
                GatekeeperAllowedSource  = $GatekeeperAllowedSource
                DefenderRiskScoreLevel   = $DefenderRiskScoreLevel
                RequiresThreatProtection = $RequiresThreatProtection
            }
        }

        function Get-TestEnrollmentProfile {
            param(
                [string] $Name = 'macOS ADE',
                [bool] $HasAdminAccount = $true,
                [bool] $HasPasswordRotation = $true,
                [int] $AutoRotationPeriodInDays = 90,
                [bool] $RotateOnRetrieval = $true
            )

            return [pscustomobject]@{
                Id                       = [guid]::NewGuid().ToString()
                Name                     = $Name
                TokenName                = 'VID ABM'
                IsDefault                = $true
                HasAdminAccount          = $HasAdminAccount
                HideAdminAccount         = $true
                HasPasswordRotation      = $HasPasswordRotation
                AutoRotationPeriodInDays = $AutoRotationPeriodInDays
                RotateOnRetrieval        = $RotateOnRetrieval
                AwaitFinalConfiguration  = $true
                UsePlatformSsoAtSetup    = $false
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

    Context 'Test-MtMacOSSystemIntegrityProtection (MT.1214)' {
        It 'passes when an assigned policy requires SIP' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -RequiresSip $true -AssignmentCount 1)
            }

            Test-MtMacOSSystemIntegrityProtection | Should -BeTrue
            $script:TestResult | Should -Match 'Required'
        }

        It 'fails when no policy requires SIP' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -RequiresSip $false -AssignmentCount 1)
            }

            Test-MtMacOSSystemIntegrityProtection | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'fails when the only policy requiring SIP is unassigned, and says so' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -RequiresSip $true -AssignmentCount 0)
            }

            Test-MtMacOSSystemIntegrityProtection | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'fails when the tenant has no macOS compliance policies' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                # Mirror the real helper: emit an empty list without unrolling it to $null.
                Write-Output ([System.Collections.Generic.List[pscustomobject]]::new()) -NoEnumerate
            }

            Test-MtMacOSSystemIntegrityProtection | Should -BeFalse
            $script:TestResult | Should -Match 'No macOS compliance policies'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy { return $null }

            Test-MtMacOSSystemIntegrityProtection | Should -BeNullOrEmpty
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }

        It 'notes assigned policies that do not require SIP even when passing' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(
                    (Get-TestCompliancePolicy -Name 'Strict' -RequiresSip $true -AssignmentCount 1),
                    (Get-TestCompliancePolicy -Name 'Lenient' -RequiresSip $false -AssignmentCount 2)
                )
            }

            Test-MtMacOSSystemIntegrityProtection | Should -BeTrue
            $script:TestResult | Should -Match 'do not require System Integrity Protection'
        }
    }

    Context 'Test-MtMacOSGatekeeper (MT.1215)' {
        It 'passes for macAppStoreAndIdentifiedDevelopers' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -GatekeeperAllowedSource 'macAppStoreAndIdentifiedDevelopers')
            }

            Test-MtMacOSGatekeeper | Should -BeTrue
        }

        It 'passes for the stricter macAppStore' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -GatekeeperAllowedSource 'macAppStore')
            }

            Test-MtMacOSGatekeeper | Should -BeTrue
        }

        It 'fails for anywhere' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -GatekeeperAllowedSource 'anywhere')
            }

            Test-MtMacOSGatekeeper | Should -BeFalse
            $script:TestResult | Should -Match 'Anywhere'
        }

        It 'fails for notConfigured' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -GatekeeperAllowedSource 'notConfigured')
            }

            Test-MtMacOSGatekeeper | Should -BeFalse
        }

        It 'does not count a restricted but unassigned policy' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -GatekeeperAllowedSource 'macAppStore' -AssignmentCount 0)
            }

            Test-MtMacOSGatekeeper | Should -BeFalse
        }

        It 'warns about an assigned anywhere policy even when another one passes' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(
                    (Get-TestCompliancePolicy -Name 'Good' -GatekeeperAllowedSource 'macAppStore'),
                    (Get-TestCompliancePolicy -Name 'Bad' -GatekeeperAllowedSource 'anywhere')
                )
            }

            Test-MtMacOSGatekeeper | Should -BeTrue
            $script:TestResult | Should -Match 'Warning'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy { return $null }

            Test-MtMacOSGatekeeper | Should -BeNullOrEmpty
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtMacOSDefenderRiskScore (MT.1216)' {
        It 'passes for a configured threshold' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -DefenderRiskScoreLevel 'medium')
            }

            Test-MtMacOSDefenderRiskScore | Should -BeTrue
        }

        It 'passes for the strictest secured level' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -DefenderRiskScoreLevel 'secured')
            }

            Test-MtMacOSDefenderRiskScore | Should -BeTrue
        }

        It 'fails for unavailable, which means the score is not evaluated' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -DefenderRiskScoreLevel 'unavailable')
            }

            Test-MtMacOSDefenderRiskScore | Should -BeFalse
            $script:TestResult | Should -Match 'Not evaluated'
        }

        It 'fails for notSet' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -DefenderRiskScoreLevel 'notSet')
            }

            Test-MtMacOSDefenderRiskScore | Should -BeFalse
        }

        It 'notes when a threshold is set without device threat protection' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -DefenderRiskScoreLevel 'medium' -RequiresThreatProtection $false)
            }

            Test-MtMacOSDefenderRiskScore | Should -BeTrue
            $script:TestResult | Should -Match 'onboarded to Microsoft Defender for Endpoint'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy { return $null }

            Test-MtMacOSDefenderRiskScore | Should -BeNullOrEmpty
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtMacOSLAPSConfiguration (MT.1217)' {
        It 'passes when a profile has an admin account with rotation' {
            Mock -ModuleName Maester Get-MtMacOSEnrollmentProfile {
                return @(Get-TestEnrollmentProfile -HasAdminAccount $true -HasPasswordRotation $true)
            }

            Test-MtMacOSLAPSConfiguration | Should -BeTrue
            $script:TestResult | Should -Match 'Every 90 days'
        }

        It 'fails when an admin account has no rotation configured' {
            Mock -ModuleName Maester Get-MtMacOSEnrollmentProfile {
                return @(Get-TestEnrollmentProfile -HasAdminAccount $true -HasPasswordRotation $false)
            }

            Test-MtMacOSLAPSConfiguration | Should -BeFalse
            $script:TestResult | Should -Match 'no password rotation'
        }

        It 'fails when no profile configures an admin account' {
            Mock -ModuleName Maester Get-MtMacOSEnrollmentProfile {
                return @(Get-TestEnrollmentProfile -HasAdminAccount $false -HasPasswordRotation $false)
            }

            Test-MtMacOSLAPSConfiguration | Should -BeFalse
            $script:TestResult | Should -Match 'not managed or rotated by Intune'
        }

        It 'fails when the tenant has no macOS enrollment profiles' {
            Mock -ModuleName Maester Get-MtMacOSEnrollmentProfile {
                Write-Output ([System.Collections.Generic.List[pscustomobject]]::new()) -NoEnumerate
            }

            Test-MtMacOSLAPSConfiguration | Should -BeFalse
            $script:TestResult | Should -Match 'No macOS Automated Device Enrollment profiles'
        }

        It 'notes when the password is not rotated after retrieval' {
            Mock -ModuleName Maester Get-MtMacOSEnrollmentProfile {
                return @(Get-TestEnrollmentProfile -RotateOnRetrieval $false)
            }

            Test-MtMacOSLAPSConfiguration | Should -BeTrue
            $script:TestResult | Should -Match 'do not rotate the password after retrieval'
        }

        It 'documents the re-enrollment scope limitation in the companion markdown' {
            # Static explanation belongs in the description, not repeated in every result.
            $md = Get-Content "$PSScriptRoot/../../public/maester/intune/Test-MtMacOSLAPSConfiguration.md" -Raw
            $md | Should -Match 'after a factory reset'
            $md | Should -Match '(?i)Scope limitation'
        }

        It 'warns about a static admin password even when another profile passes' {
            # Mirrors a real tenant: a compliant default profile alongside a test profile
            # that provisions an admin account with no rotation, which is a static password.
            Mock -ModuleName Maester Get-MtMacOSEnrollmentProfile {
                return @(
                    (Get-TestEnrollmentProfile -Name 'Mac Prod Standard' -HasAdminAccount $true -HasPasswordRotation $true  -AutoRotationPeriodInDays 90 -RotateOnRetrieval $false),
                    (Get-TestEnrollmentProfile -Name 'MacOS Test'        -HasAdminAccount $true -HasPasswordRotation $false),
                    (Get-TestEnrollmentProfile -Name 'IT'                -HasAdminAccount $false -HasPasswordRotation $false)
                )
            }

            Test-MtMacOSLAPSConfiguration | Should -BeTrue
            $script:TestResult | Should -Match 'no password rotation'
            $script:TestResult | Should -Match 'static password Intune never rotates'
            # and still reports the retrieval-rotation gap on the compliant profile
            $script:TestResult | Should -Match 'do not rotate the password after retrieval'
            # partial compliance must be flagged for review, not reported as a clean pass
            $script:Investigate | Should -BeTrue
            $script:TestResult | Should -Not -Match 'Well done'
        }

        It 'reports a clean pass without Investigate when every profile is sound' {
            Mock -ModuleName Maester Get-MtMacOSEnrollmentProfile {
                return @(
                    (Get-TestEnrollmentProfile -Name 'Mac Prod Standard'),
                    (Get-TestEnrollmentProfile -Name 'Mac Prod Frontline')
                )
            }

            Test-MtMacOSLAPSConfiguration | Should -BeTrue
            $script:Investigate | Should -BeFalse
            $script:TestResult | Should -Match 'Well done'
        }

        It 'skips as NotAuthorized when the profiles cannot be read' {
            # deviceManagement/depOnboardingSettings is gated by Intune RBAC on top of
            # the Graph scope and returns 403 for accounts without enrollment programs access.
            Mock -ModuleName Maester Get-MtMacOSEnrollmentProfile { return $null }

            Test-MtMacOSLAPSConfiguration | Should -BeNullOrEmpty
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Edge cases and unexpected data' {
        It 'does not mislabel an unrecognised Gatekeeper value as Not configured' {
            # Graph enums gain values over time (unknownFutureValue and friends).
            # Reporting a real-but-unknown setting as "Not configured" would be wrong.
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -GatekeeperAllowedSource 'someFutureAppleSource')
            }

            Test-MtMacOSGatekeeper | Should -BeFalse
            $script:TestResult | Should -Not -Match 'Not configured'
            $script:TestResult | Should -Match 'someFutureAppleSource'
        }

        It 'does not mislabel an unrecognised Defender risk level as Not evaluated' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -DefenderRiskScoreLevel 'someFutureLevel')
            }

            Test-MtMacOSDefenderRiskScore | Should -BeFalse
            $script:TestResult | Should -Not -Match 'Not evaluated'
            $script:TestResult | Should -Match 'someFutureLevel'
        }

        It 'still labels a genuinely absent Gatekeeper setting as Not configured' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -GatekeeperAllowedSource '')
            }

            Test-MtMacOSGatekeeper | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'handles a policy with an empty display name without throwing' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(Get-TestCompliancePolicy -Name '')
            }

            { Test-MtMacOSSystemIntegrityProtection } | Should -Not -Throw
        }

        It 'handles many policies with mixed states' {
            Mock -ModuleName Maester Get-MtMacOSCompliancePolicy {
                return @(
                    (Get-TestCompliancePolicy -Name 'A' -RequiresSip $true  -AssignmentCount 1),
                    (Get-TestCompliancePolicy -Name 'B' -RequiresSip $false -AssignmentCount 3),
                    (Get-TestCompliancePolicy -Name 'C' -RequiresSip $true  -AssignmentCount 0),
                    (Get-TestCompliancePolicy -Name 'D' -RequiresSip $false -AssignmentCount 0)
                )
            }

            Test-MtMacOSSystemIntegrityProtection | Should -BeTrue
            $script:TestResult | Should -Match 'Found 4 macOS compliance'
        }

        It 'reports rotation as Enabled when the period is zero rather than omitting it' {
            Mock -ModuleName Maester Get-MtMacOSEnrollmentProfile {
                return @(Get-TestEnrollmentProfile -AutoRotationPeriodInDays 0)
            }

            Test-MtMacOSLAPSConfiguration | Should -BeTrue
            $script:TestResult | Should -Match 'Enabled'
        }

        It 'handles multiple enrollment profiles where only one is compliant' {
            Mock -ModuleName Maester Get-MtMacOSEnrollmentProfile {
                return @(
                    (Get-TestEnrollmentProfile -Name 'Good' -HasAdminAccount $true  -HasPasswordRotation $true),
                    (Get-TestEnrollmentProfile -Name 'Bad'  -HasAdminAccount $false -HasPasswordRotation $false)
                )
            }

            Test-MtMacOSLAPSConfiguration | Should -BeTrue
            $script:TestResult | Should -Match 'Found 2 macOS Automated Device Enrollment'
        }
    }

    Context 'Get-MtMacOSCompliancePolicy' {
        It 'returns only macOS policies and carries assignment state' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @(
                    [pscustomobject]@{
                        id                               = 'mac-1'
                        '@odata.type'                    = '#microsoft.graph.macOSCompliancePolicy'
                        displayName                      = 'Mac Compliance'
                        systemIntegrityProtectionEnabled = $true
                        gatekeeperAllowedAppSource       = 'macAppStore'
                        assignments                      = @([pscustomobject]@{ id = 'a1' })
                    },
                    [pscustomobject]@{
                        id            = 'win-1'
                        '@odata.type' = '#microsoft.graph.windows10CompliancePolicy'
                        displayName   = 'Windows Compliance'
                        assignments   = @()
                    }
                )
            }

            InModuleScope Maester {
                $result = Get-MtMacOSCompliancePolicy
                $null -ne $result | Should -BeTrue
                $result.Count | Should -Be 1
                $result[0].Name | Should -Be 'Mac Compliance'
                $result[0].RequiresSip | Should -BeTrue
                $result[0].IsAssigned | Should -BeTrue
                $result[0].AssignmentCount | Should -Be 1
            }
        }

        It 'returns null when the request yields elements without an id' {
            # A failed Graph call surfaces as a non-terminating error with a null result,
            # which collects as a single empty element. That must not look like an empty tenant.
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @($null) }

            InModuleScope Maester {
                Get-MtMacOSCompliancePolicy | Should -BeNullOrEmpty
            }
        }

        It 'returns an empty list when the tenant genuinely has no policies' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

            InModuleScope Maester {
                $result = Get-MtMacOSCompliancePolicy
                # Must be an empty collection, NOT $null - $null means "could not read".
                $null -ne $result | Should -BeTrue
                $result.Count | Should -Be 0
            }
        }
    }

    Context 'Get-MtMacOSEnrollmentProfile' {
        It 'returns null when the enrollment tokens cannot be read' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @($null) }

            InModuleScope Maester {
                Get-MtMacOSEnrollmentProfile | Should -BeNullOrEmpty
            }
        }

        It 'returns an empty list when no Apple enrollment tokens exist' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

            InModuleScope Maester {
                $result = Get-MtMacOSEnrollmentProfile
                $null -ne $result | Should -BeTrue
                $result.Count | Should -Be 0
            }
        }

        It 'never surfaces adminAccountPassword' {
            Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
                $RelativeUri -eq 'deviceManagement/depOnboardingSettings'
            } -MockWith {
                return @([pscustomobject]@{ id = 'token-1'; tokenName = 'VID ABM' })
            }
            Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
                $RelativeUri -like '*enrollmentProfiles*'
            } -MockWith {
                return @([pscustomobject]@{
                        id                   = 'profile-1'
                        '@odata.type'        = '#microsoft.graph.depMacOSEnrollmentProfile'
                        displayName          = 'macOS ADE'
                        adminAccountUserName = 'admin'
                        adminAccountPassword = 'SuperSecret123!'
                        hideAdminAccount     = $true
                    })
            }

            InModuleScope Maester {
                $result = Get-MtMacOSEnrollmentProfile
                $result.Count | Should -Be 1
                $result[0].HasAdminAccount | Should -BeTrue
                # The password must not be carried on the returned object under any name.
                $names = $result[0].PSObject.Properties.Name
                $names | Should -Not -Contain 'adminAccountPassword'
                ($result[0] | ConvertTo-Json -Depth 5) | Should -Not -Match 'SuperSecret123'
            }
        }
    }
}
