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

    Context 'Test-MtIntuneDeviceComplianceStatus (MT.1253)' {
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
            Test-MtIntuneDeviceComplianceStatus -MaxNonCompliantPercentage 10 | Should -BeTrue
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

    Context 'Test-MtIntuneSecurityBaselineStatus (MT.1254)' {
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

        It 'skips as NotApplicable when no device has an evaluated verdict' {
            # Assigned, but every device is still unknown or not applicable: nothing to judge.
            $instance = [pscustomobject]@{ Data = (Get-TestBaseline -Unknown 10 -NotApplicable 3) }

            $null -eq (Test-MtIntuneSecurityBaselineStatus -Instance $instance) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotApplicable'
        }
    }

    Context 'Get-MtIntuneSecurityBaselineInstance (MT.1254 instance source)' {
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
            # Same reasoning as the MT.1253 guard above: anything that is not 401/403 is rethrown,
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

            InModuleScope Maester {
                $result = Get-MtSecurityBaseline
                $result.Count | Should -Be 1
                $result[0].Name | Should -Be 'Windows Baseline'
                $result[0].SecureCount | Should -Be 8
                $result[0].NotSecureCount | Should -Be 2
                $result[0].TotalDeviceCount | Should -Be 15
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

            InModuleScope Maester {
                $result = Get-MtSecurityBaseline
                $result[0].SecureCount | Should -Be 4
                $result[0].NotSecureCount | Should -Be 0
                $result[0].TotalDeviceCount | Should -Be 4
            }
        }
    }
}
