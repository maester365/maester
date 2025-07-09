Describe "Microsoft Defender Antivirus - Policy Compliance" -Tag "Maester", "MDE", "Security", "All", "MDE-Antivirus", "Defender", "Automated" {

    # Scan Engines Tests (MDE.AV01 to MDE.AV09) - Using Unified Test Engine
    It "MDE.AV01: Archive Scanning should be allowed. See https://maester.dev/docs/tests/MDE.AV01" -Tag "MDE.AV01" {
        <#
            Verify that archive scanning is enabled to detect malware in compressed files.
            Category: Scan Engines | Severity: Medium
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV01" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "archive scanning helps detect malware hidden in compressed files"
            }
        }
    }

    It "MDE.AV02: Behavior Monitoring should be allowed. See https://maester.dev/docs/tests/MDE.AV02" -Tag "MDE.AV02" {
        <#
            Verify that behavior monitoring is enabled - prerequisite for EDR capabilities.
            Category: Scan Engines | Severity: High
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV02" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "behavior monitoring is essential for detecting advanced threats"
            }
        }
    }

    It "MDE.AV03: Cloud Protection should be allowed. See https://maester.dev/docs/tests/MDE.AV03" -Tag "MDE.AV03" {
        <#
            Verify that cloud protection is enabled with CloudLevel ≥ High.
            Category: Scan Engines | Severity: High
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV03" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "cloud protection provides real-time threat intelligence"
            }
        }
    }

    It "MDE.AV04: Email Scanning should be allowed. See https://maester.dev/docs/tests/MDE.AV04" -Tag "MDE.AV04" {
        <#
            Verify that email scanning is enabled for Exchange queues protection.
            Category: Scan Engines | Severity: Medium
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV04" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "email scanning should be enabled to protect Exchange queues"
            }
        }
    }

    It "MDE.AV05: Script Scanning should be allowed. See https://maester.dev/docs/tests/MDE.AV05" -Tag "MDE.AV05" {
        <#
            Verify that script scanning is enabled to block malicious JavaScript.
            Category: Scan Engines | Severity: High
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV05" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "script scanning should be enabled to block malicious scripts"
            }
        }
    }

    It "MDE.AV06: Real-time Monitoring should be allowed. See https://maester.dev/docs/tests/MDE.AV06" -Tag "MDE.AV06" {
        <#
            Verify that realtime monitoring is enabled - core protection function.
            Category: Scan Engines | Severity: Critical
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV06" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "real-time monitoring provides essential protection against live threats"
            }
        }
    }

    It "MDE.AV07: Full Scan Removable Drives should be allowed. See https://maester.dev/docs/tests/MDE.AV07" -Tag "MDE.AV07" {
        <#
            Verify that full scan of removable drives is enabled to mitigate USB risks.
            Category: Scan Engines | Severity: Medium
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV07" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "full scan of removable drives should be enabled to mitigate USB risks"
            }
        }
    }

    It "MDE.AV08: Full Scan Mapped Drives should be disabled for performance. See https://maester.dev/docs/tests/MDE.AV08" -Tag "MDE.AV08" {
        <#
            Verify that full scan of mapped network drives is disabled for performance reasons.
            Category: Scan Engines | Severity: Low
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV08" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "full scan of mapped drives should be disabled for performance optimization"
            }
        }
    }

    It "MDE.AV09: Scanning Network Files should be allowed. See https://maester.dev/docs/tests/MDE.AV09" -Tag "MDE.AV09" {
        <#
            Verify that scanning network files is enabled despite SMB load considerations.
            Category: Scan Engines | Severity: Medium
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV09" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "scanning network files should be enabled for comprehensive protection"
            }
        }
    }

    # Performance Tests (MDE.AV10)
    It "MDE.AV10: CPU Load Factor should be optimized (20-30%). See https://maester.dev/docs/tests/MDE.AV10" -Tag "MDE.AV10" {
        <#
            Verify that average CPU load factor is configured between 20-30%.
            Category: Performance | Severity: Low
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV10" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "CPU load should be balanced between performance and security"
            }
        }
    }

    # Scheduling Tests (MDE.AV11 to MDE.AV12)
    It "MDE.AV11: Scan should be scheduled every day. See https://maester.dev/docs/tests/MDE.AV11" -Tag "MDE.AV11" {
        <#
            Verify that scans are scheduled for every day during off-hours.
            Category: Scheduling | Severity: Medium
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV11" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "scans should be scheduled every day for comprehensive coverage"
            }
        }
    }

    It "MDE.AV12: Quick Scan Time configuration should not be required. See https://maester.dev/docs/tests/MDE.AV12" -Tag "MDE.AV12" {
        <#
            Verify that quick scan time is not configured (not required).
            Category: Scheduling | Severity: Low
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV12" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "quick scan time configuration is not required"
            }
        }
    }

    # Signature & Cloud Tests (MDE.AV13 to MDE.AV16)
    It "MDE.AV13: Signatures should be checked before scan. See https://maester.dev/docs/tests/MDE.AV13" -Tag "MDE.AV13" {
        <#
            Verify that signature checking before scan is enabled for zero-day protection.
            Category: Signature & Cloud | Severity: High
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV13" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "signatures should be checked before scan for zero-day protection"
            }
        }
    }

    It "MDE.AV14: Cloud Block Level should be High or higher. See https://maester.dev/docs/tests/MDE.AV14" -Tag "MDE.AV14" {
        <#
            Verify that cloud block level is set to High, High+, or Zero Tolerance.
            Category: Signature & Cloud | Severity: High
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV14" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "cloud block level should be High or higher for maximum protection"
            }
        }
    }

    It "MDE.AV15: Cloud Extended Timeout should be 30-50 seconds. See https://maester.dev/docs/tests/MDE.AV15" -Tag "MDE.AV15" {
        <#
            Verify that cloud extended timeout is configured between 30-50 seconds (UX vs Detection balance).
            Category: Signature & Cloud | Severity: Medium
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV15" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "cloud extended timeout should be 30-50 seconds for optimal UX and detection"
            }
        }
    }

    It "MDE.AV16: Signature Update Interval should be 1-4 hours. See https://maester.dev/docs/tests/MDE.AV16" -Tag "MDE.AV16" {
        <#
            Verify that signature update interval is configured between 1-4 hours considering bandwidth.
            Category: Signature & Cloud | Severity: High
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV16" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "signature update interval should be 1-4 hours for current protection"
            }
        }
    }

    # Protection Tests (MDE.AV17 to MDE.AV21)
    It "MDE.AV17: PUA Protection should be enabled to block potentially unwanted applications. See https://maester.dev/docs/tests/MDE.AV17" -Tag "MDE.AV17"{
        <#
            Verify that PUA (Potentially Unwanted Applications) protection is enabled to block Shadow IT.
            Category: Protection | Severity: High
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV17" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "PUA protection should be enabled to block potentially unwanted applications"
            }
        }
    }

    It "MDE.AV18: Network Protection should be enabled in block mode. See https://maester.dev/docs/tests/MDE.AV18" -Tag "MDE.AV18" {
        <#
            Verify that Network Protection is enabled in block mode.
            Category: Protection | Severity: High
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV18" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "network protection should be enabled in block mode"
            }
        }
    }

    It "MDE.AV19: Local Admin Merge should be disabled. See https://maester.dev/docs/tests/MDE.AV19" -Tag "MDE.AV19" {
        <#
            Verify that local admin merge is disabled to block local exclusions.
            Category: Protection | Severity: Critical
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV19" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "local admin merge should be disabled to prevent local exclusions"
            }
        }
    }

    It "MDE.AV20: Tamper Protection should be enabled tenant-wide. See https://maester.dev/docs/tests/MDE.AV20" -Tag "MDE.AV20" {
        <#
            Verify that Tamper Protection is enabled tenant-wide.
            Category: Protection | Severity: Critical
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV20" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "tamper protection should be enabled tenant-wide"
            }
        }
    }

    It "MDE.AV21: Real-Time Scan Direction should be configured for both directions. See https://maester.dev/docs/tests/MDE.AV21" -Tag "MDE.AV21" {
        <#
            Verify that real-time scan direction is set to both incoming and outgoing.
            Category: Protection | Severity: Medium
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV21" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "real-time scan should monitor both incoming and outgoing traffic"
            }
        }
    }

    # Cleanup & Quarantine Tests (MDE.AV22 to MDE.AV26)
    It "MDE.AV22: Cleaned Malware should be retained for 90 days. See https://maester.dev/docs/tests/MDE.AV22" -Tag "MDE.AV22"{
        <#
            Verify that cleaned malware is retained for 90 days for audit purposes.
            Category: Cleanup & Quarantine | Severity: Medium
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV22" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "cleaned malware should be retained for 90 days for audit purposes"
            }
        }
    }

    It "MDE.AV23: Catch-up Full Scan should be disabled. See https://maester.dev/docs/tests/MDE.AV23" -Tag "MDE.AV23" {
        <#
            Verify that catch-up full scan is disabled to avoid additional load.
            Category: Cleanup & Quarantine | Severity: Low
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV23" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "catch-up full scan should be disabled to avoid additional system load"
            }
        }
    }

    It "MDE.AV24: Catch-up Quick Scan should be disabled. See https://maester.dev/docs/tests/MDE.AV24" -Tag "MDE.AV24" {
        <#
            Verify that catch-up quick scan is disabled.
            Category: Cleanup & Quarantine | Severity: Low
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV24" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "catch-up quick scan should be disabled"
            }
        }
    }

    It "MDE.AV25: Remediation Action should be set to Quarantine. See https://maester.dev/docs/tests/MDE.AV25" -Tag "MDE.AV25" {
        <#
            Verify that remediation action for all threat levels is set to Quarantine.
            Category: Cleanup & Quarantine | Severity: High
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV25" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "remediation action should be consistently set to quarantine for all threat levels"
            }
        }
    }

    It "MDE.AV26: Sample Submission should be configured to send safe samples automatically. See https://maester.dev/docs/tests/MDE.AV26" -Tag "MDE.AV26" {
        <#
            Verify that sample submission consent is configured to send safe samples automatically.
            Category: Cleanup & Quarantine | Severity: Medium
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.AV26" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "sample submission should be configured to send safe samples automatically"
            }
        }
    }
}