Describe 'Intune device compliance and security baseline status' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # These functions became native tests and an instance source; they are not exported.
        Use-MtModuleFunction -Name Test-MtIntuneDeviceComplianceStatus, Test-MtIntuneSecurityBaselineStatus, Get-MtIntuneSecurityBaselineInstance

        function Get-TestDevice {
            param(
                [string] $ComplianceState = 'compliant',
                [string] $Name = 'Device',
                [string] $OperatingSystem = 'Windows'
            )
            return [pscustomobject]@{
                Id              = [guid]::NewGuid().ToString()
                Name            = $Name
                OperatingSystem = $OperatingSystem
                ComplianceState = $ComplianceState
            }
        }

        function Get-TestDeviceSet {
            # Produces $Count devices of a single compliance state.
            param([string] $ComplianceState, [int] $Count)
            1..$Count | ForEach-Object { Get-TestDevice -ComplianceState $ComplianceState }
        }

        function Get-TestBaseline {
            param(
                [string] $Name = 'Windows Security Baseline',
                [int] $Secure = 0,
                [int] $NotSecure = 0,
                [int] $Conflict = 0,
                [int] $ErrorDevices = 0,
                [int] $Unknown = 0,
                [int] $NotApplicable = 0
            )
            return [pscustomobject]@{
                Kind               = 'Template'
                Id                 = [guid]::NewGuid().ToString()
                Name               = $Name
                SecureCount        = $Secure
                NotSecureCount     = $NotSecure
                ConflictCount      = $Conflict
                ErrorCount         = $ErrorDevices
                UnknownCount       = $Unknown
                NotApplicableCount = $NotApplicable
                TotalDeviceCount   = $Secure + $NotSecure + $Conflict + $ErrorDevices + $Unknown + $NotApplicable
            }
        }

        function Get-TestSettingsCatalogBaseline {
            # The current kind of baseline: no device counts exist for it, only assignments.
            param(
                [string] $Name = 'Security Baseline for Windows 10 and later',
                [int] $Assignments = 1
            )
            return [pscustomobject]@{
                Kind            = 'SettingsCatalog'
                Id              = [guid]::NewGuid().ToString()
                Name            = $Name
                AssignmentCount = $Assignments
            }
        }
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null
        $script:SkippedCustomReason = $null

        Mock -ModuleName Maester Get-MtLicenseInformation { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedCustomReason)

            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
            $script:SkippedCustomReason = $SkippedCustomReason
        }
    }

    Context 'Test-MtIntuneDeviceComplianceStatus (MT.1267)' {
        It 'passes when the non-compliant share is at or below the threshold' {
            Mock -ModuleName Maester Get-MtManagedDeviceCompliance {
                return @((Get-TestDeviceSet -ComplianceState 'compliant' -Count 19) + (Get-TestDevice -ComplianceState 'noncompliant'))
            }

            Test-MtIntuneDeviceComplianceStatus | Should -BeTrue
            $script:TestResult | Should -Match '5%'
        }

        It 'fails when the non-compliant share is above the threshold' {
            Mock -ModuleName Maester Get-MtManagedDeviceCompliance {
                return @((Get-TestDeviceSet -ComplianceState 'compliant' -Count 18) + (Get-TestDeviceSet -ComplianceState 'noncompliant' -Count 2))
            }

            Test-MtIntuneDeviceComplianceStatus | Should -BeFalse
            $script:TestResult | Should -Match 'above the threshold'
        }

        It 'counts conflict, error and grace-period devices as non-compliant' {
            Mock -ModuleName Maester Get-MtManagedDeviceCompliance {
                @(Get-TestDeviceSet -ComplianceState 'compliant' -Count 6) +
                @(Get-TestDevice -ComplianceState 'conflict') +
                @(Get-TestDevice -ComplianceState 'error') +
                @(Get-TestDevice -ComplianceState 'ingraceperiod')
            }

            # 3 of 9 evaluated devices are non-compliant = 33.3%, above the default 5%.
            Test-MtIntuneDeviceComplianceStatus | Should -BeFalse
            $script:TestResult | Should -Match '33.3%'
        }

        It 'respects a custom threshold set as a parameter' {
            Mock -ModuleName Maester Get-MtManagedDeviceCompliance {
                return @((Get-TestDeviceSet -ComplianceState 'compliant' -Count 18) + (Get-TestDeviceSet -ComplianceState 'noncompliant' -Count 2))
            }

            # 10% is above the default 5% (fail) but at the custom 10% (pass).
            Test-MtIntuneDeviceComplianceStatus -MaximumNonCompliantPercentage 10 | Should -BeTrue
        }

        It 'skips as NotApplicable when the tenant has no managed devices' {
            Mock -ModuleName Maester Get-MtManagedDeviceCompliance {
                # Mirror the real helper: emit an empty list without unrolling it to $null.
                Write-Output ([System.Collections.Generic.List[pscustomobject]]::new()) -NoEnumerate
            }

            $null -eq (Test-MtIntuneDeviceComplianceStatus) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotApplicable'
        }

        It 'skips as NotApplicable when no device has reported a verdict' {
            # unknown and configManager carry no compliance verdict, so there is nothing to measure.
            Mock -ModuleName Maester Get-MtManagedDeviceCompliance {
                return @((Get-TestDeviceSet -ComplianceState 'unknown' -Count 4) + (Get-TestDevice -ComplianceState 'configmanager'))
            }

            $null -eq (Test-MtIntuneDeviceComplianceStatus) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotApplicable'
        }

        It 'does not count unknown or configManager devices in the share' {
            # 1 non-compliant out of 20 evaluated = 5% (pass). The 100 unknown devices must not dilute it.
            Mock -ModuleName Maester Get-MtManagedDeviceCompliance {
                @(Get-TestDeviceSet -ComplianceState 'compliant' -Count 19) +
                @(Get-TestDevice -ComplianceState 'noncompliant') +
                @(Get-TestDeviceSet -ComplianceState 'unknown' -Count 100)
            }

            Test-MtIntuneDeviceComplianceStatus | Should -BeTrue
        }

        It 'skips as NotAuthorized when the devices cannot be read' {
            Mock -ModuleName Maester Get-MtManagedDeviceCompliance { return $null }

            $null -eq (Test-MtIntuneDeviceComplianceStatus) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }

        It 'does not disguise a non-permission failure as a skip' {
            # The guard around the retrieval maps 401/403 to NotAuthorized and rethrows anything else,
            # so a defect in the retrieval surfaces as an error instead of a silent skip.
            Mock -ModuleName Maester Get-MtManagedDeviceCompliance { throw 'unexpected failure' }

            { Test-MtIntuneDeviceComplianceStatus } | Should -Throw
            $script:SkippedBecause | Should -BeNullOrEmpty
        }
    }

    Context 'Get-MtManagedDeviceCompliance' {
        It 'normalises the compliance state and keeps only devices with an id' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @(
                    [pscustomobject]@{ id = 'd1'; deviceName = 'Laptop'; operatingSystem = 'Windows'; complianceState = 'Compliant' },
                    [pscustomobject]@{ id = 'd2'; deviceName = 'Phone'; operatingSystem = 'iOS'; complianceState = 'NonCompliant' }
                )
            }

            InModuleScope Maester {
                $result = Get-MtManagedDeviceCompliance
                $result.Count | Should -Be 2
                $result[0].ComplianceState | Should -Be 'compliant'
                $result[1].ComplianceState | Should -Be 'noncompliant'
            }
        }

        It 'returns null when the request yields elements without an id' {
            # A failed Graph call surfaces as a non-terminating error with a null result,
            # which collects as a single empty element. That must not look like an empty tenant.
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @($null) }

            InModuleScope Maester {
                $null -eq (Get-MtManagedDeviceCompliance) | Should -BeTrue
            }
        }

        It 'returns an empty list when the tenant genuinely has no devices' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

            InModuleScope Maester {
                $result = Get-MtManagedDeviceCompliance
                # Must be an empty collection, NOT $null - $null means "could not read".
                $null -ne $result | Should -BeTrue
                $result.Count | Should -Be 0
            }
        }
    }

    Context 'Test-MtIntuneSecurityBaselineStatus (MT.1268)' {
        It 'passes when every evaluated device is secure' {
            $instance = [pscustomobject]@{ Data = (Get-TestBaseline -Secure 25) }

            Test-MtIntuneSecurityBaselineStatus -Instance $instance | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'fails when a device is not secure' {
            $instance = [pscustomobject]@{ Data = (Get-TestBaseline -Secure 20 -NotSecure 5) }

            Test-MtIntuneSecurityBaselineStatus -Instance $instance | Should -BeFalse
            $script:TestResult | Should -Match 'do not match this baseline'
        }

        It 'fails when a device is in conflict or error' {
            $instance = [pscustomobject]@{ Data = (Get-TestBaseline -Secure 20 -Conflict 1 -ErrorDevices 1) }

            Test-MtIntuneSecurityBaselineStatus -Instance $instance | Should -BeFalse
        }

        It 'reports a settings catalog baseline and skips it instead of judging it' {
            # Intune publishes no per-device compliance summary for this kind through a documented API.
            # The baseline must still appear by name, with its assignment count: the failure this
            # replaces was the family reporting that there was nothing in the tenant to check while a
            # settings catalog baseline sat in error on its device.
            $instance = [pscustomobject]@{ Data = (Get-TestSettingsCatalogBaseline -Name 'Windows 26H2' -Assignments 2) }

            $null -eq (Test-MtIntuneSecurityBaselineStatus -Instance $instance) | Should -BeTrue
            # Not NotApplicable: the engine writes "This test does not apply to this tenant." for that,
            # which contradicts a result stating the baseline is assigned.
            $script:SkippedBecause | Should -Be 'Custom'
            $script:SkippedCustomReason | Should -Match 'no per-device state'
            $script:TestResult | Should -Match 'Windows 26H2'
            $script:TestResult | Should -Match 'assigned to 2 group'
            # It must not claim a verdict it cannot have.
            $script:TestResult | Should -Not -Match 'Well done'
        }

        It 'escapes a baseline name that carries markdown' {
            # A baseline name is written by a tenant admin and lands in the report. Without escaping,
            # a name like the one below renders as a clickable link in the result.
            $hostil = '[Sign in again](https://phish.example)'
            $settingsCatalog = [pscustomobject]@{ Data = (Get-TestSettingsCatalogBaseline -Name $hostil) }
            $null -eq (Test-MtIntuneSecurityBaselineStatus -Instance $settingsCatalog) | Should -BeTrue
            $script:TestResult | Should -Match '\\\[Sign in again'

            $legacy = [pscustomobject]@{ Data = (Get-TestBaseline -Name $hostil -Secure 3) }
            Test-MtIntuneSecurityBaselineStatus -Instance $legacy | Should -BeTrue
            $script:TestResult | Should -Match '\\\[Sign in again'
        }

        It 'skips with its own reason when no device has an evaluated verdict' {
            # Assigned, but every device is still unknown or not applicable: nothing to judge. The
            # reason has to say that, because "does not apply to this tenant" is the opposite of a
            # baseline the tenant has assigned.
            $instance = [pscustomobject]@{ Data = (Get-TestBaseline -Unknown 10 -NotApplicable 3) }

            $null -eq (Test-MtIntuneSecurityBaselineStatus -Instance $instance) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'Custom'
            $script:SkippedCustomReason | Should -Match 'no device has reported'
        }

        It 'keeps the two baseline skips apart' {
            # A settings catalog baseline and a legacy one with no verdict are different situations and
            # must not collapse into one reason.
            $null = Test-MtIntuneSecurityBaselineStatus -Instance ([pscustomobject]@{ Data = (Get-TestSettingsCatalogBaseline -Name 'A' -Assignments 1) })
            $catalogo = $script:SkippedCustomReason

            $null = Test-MtIntuneSecurityBaselineStatus -Instance ([pscustomobject]@{ Data = (Get-TestBaseline -Unknown 4) })
            $sinVeredicto = $script:SkippedCustomReason

            $catalogo | Should -Not -Be $sinVeredicto
        }
    }

    Context 'Get-MtIntuneSecurityBaselineInstance (MT.1268 instance source)' {
        It 'emits one instance per deployed baseline and leaves undeployed ones out' {
            Mock -ModuleName Maester Get-MtSecurityBaseline {
                return @(
                    (Get-TestBaseline -Name 'Deployed A' -Secure 10),
                    (Get-TestBaseline -Name 'Deployed B' -Secure 5 -NotSecure 2),
                    (Get-TestBaseline -Name 'Never assigned')   # TotalDeviceCount = 0
                )
            }

            $instances = @(Get-MtIntuneSecurityBaselineInstance)
            $instances.Count | Should -Be 2
            $instances.Title | Should -Not -Contain "Security baseline 'Never assigned' should report every device as secure."
            $script:SkippedBecause | Should -BeNullOrEmpty
        }

        It 'emits assigned settings catalog baselines and leaves unassigned ones out' {
            # No device count exists for this kind, so deployment is read from the assignments.
            Mock -ModuleName Maester Get-MtSecurityBaseline {
                return @(
                    (Get-TestSettingsCatalogBaseline -Name 'Assigned baseline' -Assignments 1),
                    (Get-TestSettingsCatalogBaseline -Name 'Unassigned baseline' -Assignments 0),
                    (Get-TestBaseline -Name 'Legacy deployed' -Secure 3)
                )
            }

            $instances = @(Get-MtIntuneSecurityBaselineInstance)
            $instances.Count | Should -Be 2
            $instances.Title | Should -Contain "Security baseline 'Assigned baseline' should report every device as secure."
            $instances.Title | Should -Not -Contain "Security baseline 'Unassigned baseline' should report every device as secure."
            $instances.Title | Should -Contain "Security baseline 'Legacy deployed' should report every device as secure."
        }

        It 'skips the family as NotAuthorized when the baselines cannot be read' {
            Mock -ModuleName Maester Get-MtSecurityBaseline { return $null }

            $instances = @(Get-MtIntuneSecurityBaselineInstance)
            $instances.Count | Should -Be 0
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }

        It 'skips the family as NotAuthorized when the baseline read throws 403' {
            # The helper has two failure paths. The case above is the one where it returns $null;
            # this is the one where it lets a terminating error through, which used to reach the
            # engine as InstanceSourceFailed rather than the skip this source documents.
            Mock -ModuleName Maester Get-MtSecurityBaseline {
                $respuesta = [pscustomobject]@{ StatusCode = 403 }
                $excepcion = [System.Exception]::new('Forbidden')
                $excepcion | Add-Member -NotePropertyName Response -NotePropertyValue $respuesta -Force
                throw $excepcion
            }

            $instances = @(Get-MtIntuneSecurityBaselineInstance)
            $instances.Count | Should -Be 0
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }

        It 'does not disguise a non-permission baseline failure as a skip' {
            # Same reasoning as the MT.1267 guard above: anything that is not 401/403 is rethrown,
            # so a defect in the retrieval surfaces as an error instead of a silent skip.
            Mock -ModuleName Maester Get-MtSecurityBaseline { throw 'unexpected failure' }

            { Get-MtIntuneSecurityBaselineInstance } | Should -Throw
            $script:SkippedBecause | Should -BeNullOrEmpty
        }
    }

    Context 'Get-MtSecurityBaseline' {
        It 'returns the per-state device counts for each baseline' {
            Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
                $RelativeUri -eq 'deviceManagement/templates'
            } -MockWith {
                return @([pscustomobject]@{ id = 'tmpl-1'; displayName = 'Windows Baseline' })
            }
            Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
                $RelativeUri -like '*deviceStateSummary*'
            } -MockWith {
                return [pscustomobject]@{ id = 's1'; secureCount = 8; notSecureCount = 2; conflictCount = 1; errorCount = 0; unknownCount = 3; notApplicableCount = 1 }
            }
            Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
                $RelativeUri -like 'deviceManagement/configurationPolicies*'
            } -MockWith { return @() }

            InModuleScope Maester {
                $result = Get-MtSecurityBaseline
                $result.Count | Should -Be 1
                $result[0].Name | Should -Be 'Windows Baseline'
                $result[0].SecureCount | Should -Be 8
                $result[0].NotSecureCount | Should -Be 2
                $result[0].TotalDeviceCount | Should -Be 15
            }
        }

        It 'returns the settings catalog baselines with their assignment count' {
            Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
                $RelativeUri -eq 'deviceManagement/templates'
            } -MockWith { return @() }
            Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
                $RelativeUri -like 'deviceManagement/configurationPolicies*'
            } -MockWith {
                # configurationPolicies carries 'name', not 'displayName'.
                return @(
                    [pscustomobject]@{ id = 'pol-1'; name = 'Windows 26H2'; assignments = @([pscustomobject]@{ id = 'a1' }, [pscustomobject]@{ id = 'a2' }) },
                    [pscustomobject]@{ id = 'pol-2'; name = 'Microsoft Edge'; assignments = @() }
                )
            }

            InModuleScope Maester {
                $result = Get-MtSecurityBaseline
                $result.Count | Should -Be 2
                $result[0].Kind | Should -Be 'SettingsCatalog'
                $result[0].Name | Should -Be 'Windows 26H2'
                $result[0].AssignmentCount | Should -Be 2
                $result[1].AssignmentCount | Should -Be 0
            }
        }

        It 'returns null when the settings catalog request yields elements without an id' {
            # Same reasoning as the templates read: a failed call collects as a single empty element,
            # and treating that as "this tenant has no current baselines" would hide a permission
            # problem behind a clean result.
            Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
                $RelativeUri -eq 'deviceManagement/templates'
            } -MockWith { return @() }
            Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
                $RelativeUri -like 'deviceManagement/configurationPolicies*'
            } -MockWith { return @($null) }

            InModuleScope Maester {
                $null -eq (Get-MtSecurityBaseline) | Should -BeTrue
            }
        }

        It 'returns null when the templates request yields elements without an id' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @($null) }

            InModuleScope Maester {
                $null -eq (Get-MtSecurityBaseline) | Should -BeTrue
            }
        }

        It 'returns an empty list when the tenant has no security baselines' {
            Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
                $RelativeUri -eq 'deviceManagement/templates'
            } -MockWith { return @() }
            Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
                $RelativeUri -like 'deviceManagement/configurationPolicies*'
            } -MockWith { return @() }

            InModuleScope Maester {
                $result = Get-MtSecurityBaseline
                $null -ne $result | Should -BeTrue
                $result.Count | Should -Be 0
            }
        }

        It 'treats a missing count as zero rather than throwing' {
            Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
                $RelativeUri -eq 'deviceManagement/templates'
            } -MockWith {
                return @([pscustomobject]@{ id = 'tmpl-1'; displayName = 'Sparse Baseline' })
            }
            Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
                $RelativeUri -like '*deviceStateSummary*'
            } -MockWith {
                # Only a secure count is present; everything else is absent.
                return [pscustomobject]@{ id = 's1'; secureCount = 4 }
            }
            Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
                $RelativeUri -like 'deviceManagement/configurationPolicies*'
            } -MockWith { return @() }

            InModuleScope Maester {
                $result = Get-MtSecurityBaseline
                $result[0].SecureCount | Should -Be 4
                $result[0].NotSecureCount | Should -Be 0
                $result[0].TotalDeviceCount | Should -Be 4
            }
        }
    }
}
