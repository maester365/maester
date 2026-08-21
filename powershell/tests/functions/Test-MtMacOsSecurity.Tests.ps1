Describe 'macOS Intune security checks' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force

        function New-TestCompliancePolicy {
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

        function New-TestEnrollmentProfile {
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

        Mock -ModuleName Maester Get-MtLicenseInformation { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause)

            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
        }
    }

    Context 'Test-MtMacOsSystemIntegrityProtection (MT.1214)' {
        It 'passes when an assigned policy requires SIP' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(New-TestCompliancePolicy -RequiresSip $true -AssignmentCount 1)
            }

            Test-MtMacOsSystemIntegrityProtection | Should -BeTrue
            $script:TestResult | Should -Match 'Required'
        }

        It 'fails when no policy requires SIP' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(New-TestCompliancePolicy -RequiresSip $false -AssignmentCount 1)
            }

            Test-MtMacOsSystemIntegrityProtection | Should -BeFalse
            $script:TestResult | Should -Match 'Not configured'
        }

        It 'fails when the only policy requiring SIP is unassigned, and says so' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(New-TestCompliancePolicy -RequiresSip $true -AssignmentCount 0)
            }

            Test-MtMacOsSystemIntegrityProtection | Should -BeFalse
            $script:TestResult | Should -Match 'not assigned'
        }

        It 'fails when the tenant has no macOS compliance policies' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                # Mirror the real helper: emit an empty list without unrolling it to $null.
                Write-Output ([System.Collections.Generic.List[pscustomobject]]::new()) -NoEnumerate
            }

            Test-MtMacOsSystemIntegrityProtection | Should -BeFalse
            $script:TestResult | Should -Match 'No macOS compliance policies'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy { return $null }

            Test-MtMacOsSystemIntegrityProtection | Should -BeNullOrEmpty
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }

        It 'notes assigned policies that do not require SIP even when passing' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(
                    (New-TestCompliancePolicy -Name 'Strict' -RequiresSip $true -AssignmentCount 1),
                    (New-TestCompliancePolicy -Name 'Lenient' -RequiresSip $false -AssignmentCount 2)
                )
            }

            Test-MtMacOsSystemIntegrityProtection | Should -BeTrue
            $script:TestResult | Should -Match 'do not require System Integrity Protection'
        }
    }

    Context 'Test-MtMacOsGatekeeper (MT.1215)' {
        It 'passes for macAppStoreAndIdentifiedDevelopers' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(New-TestCompliancePolicy -GatekeeperAllowedSource 'macAppStoreAndIdentifiedDevelopers')
            }

            Test-MtMacOsGatekeeper | Should -BeTrue
        }

        It 'passes for the stricter macAppStore' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(New-TestCompliancePolicy -GatekeeperAllowedSource 'macAppStore')
            }

            Test-MtMacOsGatekeeper | Should -BeTrue
        }

        It 'fails for anywhere' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(New-TestCompliancePolicy -GatekeeperAllowedSource 'anywhere')
            }

            Test-MtMacOsGatekeeper | Should -BeFalse
            $script:TestResult | Should -Match 'Anywhere'
        }

        It 'fails for notConfigured' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(New-TestCompliancePolicy -GatekeeperAllowedSource 'notConfigured')
            }

            Test-MtMacOsGatekeeper | Should -BeFalse
        }

        It 'does not count a restricted but unassigned policy' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(New-TestCompliancePolicy -GatekeeperAllowedSource 'macAppStore' -AssignmentCount 0)
            }

            Test-MtMacOsGatekeeper | Should -BeFalse
        }

        It 'warns about an assigned anywhere policy even when another one passes' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(
                    (New-TestCompliancePolicy -Name 'Good' -GatekeeperAllowedSource 'macAppStore'),
                    (New-TestCompliancePolicy -Name 'Bad' -GatekeeperAllowedSource 'anywhere')
                )
            }

            Test-MtMacOsGatekeeper | Should -BeTrue
            $script:TestResult | Should -Match 'Warning'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy { return $null }

            Test-MtMacOsGatekeeper | Should -BeNullOrEmpty
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtMacOsDefenderRiskScore (MT.1216)' {
        It 'passes for a configured threshold' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(New-TestCompliancePolicy -DefenderRiskScoreLevel 'medium')
            }

            Test-MtMacOsDefenderRiskScore | Should -BeTrue
        }

        It 'passes for the strictest secured level' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(New-TestCompliancePolicy -DefenderRiskScoreLevel 'secured')
            }

            Test-MtMacOsDefenderRiskScore | Should -BeTrue
        }

        It 'fails for unavailable, which means the score is not evaluated' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(New-TestCompliancePolicy -DefenderRiskScoreLevel 'unavailable')
            }

            Test-MtMacOsDefenderRiskScore | Should -BeFalse
            $script:TestResult | Should -Match 'Not evaluated'
        }

        It 'fails for notSet' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(New-TestCompliancePolicy -DefenderRiskScoreLevel 'notSet')
            }

            Test-MtMacOsDefenderRiskScore | Should -BeFalse
        }

        It 'notes when a threshold is set without device threat protection' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy {
                return @(New-TestCompliancePolicy -DefenderRiskScoreLevel 'medium' -RequiresThreatProtection $false)
            }

            Test-MtMacOsDefenderRiskScore | Should -BeTrue
            $script:TestResult | Should -Match 'onboarded to Microsoft Defender for Endpoint'
        }

        It 'skips as NotAuthorized when the policies cannot be read' {
            Mock -ModuleName Maester Get-MtMacOsCompliancePolicy { return $null }

            Test-MtMacOsDefenderRiskScore | Should -BeNullOrEmpty
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Test-MtMacOsLAPSConfiguration (MT.1217)' {
        It 'passes when a profile has an admin account with rotation' {
            Mock -ModuleName Maester Get-MtMacOsEnrollmentProfile {
                return @(New-TestEnrollmentProfile -HasAdminAccount $true -HasPasswordRotation $true)
            }

            Test-MtMacOsLAPSConfiguration | Should -BeTrue
            $script:TestResult | Should -Match 'Every 90 days'
        }

        It 'fails when an admin account has no rotation configured' {
            Mock -ModuleName Maester Get-MtMacOsEnrollmentProfile {
                return @(New-TestEnrollmentProfile -HasAdminAccount $true -HasPasswordRotation $false)
            }

            Test-MtMacOsLAPSConfiguration | Should -BeFalse
            $script:TestResult | Should -Match 'no password rotation'
        }

        It 'fails when no profile configures an admin account' {
            Mock -ModuleName Maester Get-MtMacOsEnrollmentProfile {
                return @(New-TestEnrollmentProfile -HasAdminAccount $false -HasPasswordRotation $false)
            }

            Test-MtMacOsLAPSConfiguration | Should -BeFalse
            $script:TestResult | Should -Match 'not managed or rotated by Intune'
        }

        It 'fails when the tenant has no macOS enrollment profiles' {
            Mock -ModuleName Maester Get-MtMacOsEnrollmentProfile {
                Write-Output ([System.Collections.Generic.List[pscustomobject]]::new()) -NoEnumerate
            }

            Test-MtMacOsLAPSConfiguration | Should -BeFalse
            $script:TestResult | Should -Match 'No macOS Automated Device Enrollment profiles'
        }

        It 'notes when the password is not rotated after retrieval' {
            Mock -ModuleName Maester Get-MtMacOsEnrollmentProfile {
                return @(New-TestEnrollmentProfile -RotateOnRetrieval $false)
            }

            Test-MtMacOsLAPSConfiguration | Should -BeTrue
            $script:TestResult | Should -Match 'do not rotate the password after it is retrieved'
        }

        It 'always states the re-enrollment scope limitation when passing' {
            Mock -ModuleName Maester Get-MtMacOsEnrollmentProfile {
                return @(New-TestEnrollmentProfile)
            }

            Test-MtMacOsLAPSConfiguration | Should -BeTrue
            $script:TestResult | Should -Match 'after a factory reset'
        }

        It 'skips as NotAuthorized when the profiles cannot be read' {
            # deviceManagement/depOnboardingSettings is gated by Intune RBAC on top of
            # the Graph scope and returns 403 for accounts without enrollment programs access.
            Mock -ModuleName Maester Get-MtMacOsEnrollmentProfile { return $null }

            Test-MtMacOsLAPSConfiguration | Should -BeNullOrEmpty
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }
    }

    Context 'Get-MtMacOsCompliancePolicy' {
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
                $result = Get-MtMacOsCompliancePolicy
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
                Get-MtMacOsCompliancePolicy | Should -BeNullOrEmpty
            }
        }

        It 'returns an empty list when the tenant genuinely has no policies' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

            InModuleScope Maester {
                $result = Get-MtMacOsCompliancePolicy
                # Must be an empty collection, NOT $null - $null means "could not read".
                $null -ne $result | Should -BeTrue
                $result.Count | Should -Be 0
            }
        }
    }

    Context 'Get-MtMacOsEnrollmentProfile' {
        It 'returns null when the enrollment tokens cannot be read' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @($null) }

            InModuleScope Maester {
                Get-MtMacOsEnrollmentProfile | Should -BeNullOrEmpty
            }
        }

        It 'returns an empty list when no Apple enrollment tokens exist' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

            InModuleScope Maester {
                $result = Get-MtMacOsEnrollmentProfile
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
                $result = Get-MtMacOsEnrollmentProfile
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
