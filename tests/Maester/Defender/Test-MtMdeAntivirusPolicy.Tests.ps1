Describe "MDE" -Tag "Maester", "MDE", "MDE-Antivirus", "Defender", "Security", "All" {
    It "MDE.AV01: Archive Scanning should be enabled. See https://maester.dev/docs/tests/MDE.AV01" -Tag "MDE.AV01" {
        $result = Test-MtMdeArchiveScanning
        if ($null -ne $result) {
            $result | Should -Be $true -Because "archive scanning helps detect malware in compressed files"
        }
    }

    It "MDE.AV02: Behavior Monitoring should be enabled. See https://maester.dev/docs/tests/MDE.AV02" -Tag "MDE.AV02" {
        $result = Test-MtMdeBehaviorMonitoring
        if ($null -ne $result) {
            $result | Should -Be $true -Because "behavior monitoring is essential for detecting advanced threats"
        }
    }

    It "MDE.AV03: Cloud Protection should be enabled. See https://maester.dev/docs/tests/MDE.AV03" -Tag "MDE.AV03" {
        $result = Test-MtMdeCloudProtection
        if ($null -ne $result) {
            $result | Should -Be $true -Because "cloud protection provides real-time threat intelligence"
        }
    }

    It "MDE.AV04: Email Scanning should be enabled. See https://maester.dev/docs/tests/MDE.AV04" -Tag "MDE.AV04" {
        $result = Test-MtMdeEmailScanning
        if ($null -ne $result) {
            $result | Should -Be $true -Because "email scanning should be enabled to protect Exchange queues"
        }
    }

    It "MDE.AV05: Script Scanning should be enabled. See https://maester.dev/docs/tests/MDE.AV05" -Tag "MDE.AV05" {
        $result = Test-MtMdeScriptScanning
        if ($null -ne $result) {
            $result | Should -Be $true -Because "script scanning should be enabled to block malicious scripts"
        }
    }

    It "MDE.AV06: Real-time Monitoring should be enabled. See https://maester.dev/docs/tests/MDE.AV06" -Tag "MDE.AV06" {
        $result = Test-MtMdeRealtimeMonitoring
        if ($null -ne $result) {
            $result | Should -Be $true -Because "real-time monitoring provides essential protection against live threats"
        }
    }

    It "MDE.AV07: Full Scan Removable Drives should be enabled. See https://maester.dev/docs/tests/MDE.AV07" -Tag "MDE.AV07" {
        $result = Test-MtMdeRemovableDriveScanning
        if ($null -ne $result) {
            $result | Should -Be $true -Because "full scan of removable drives should be enabled to mitigate USB risks"
        }
    }

    It "MDE.AV08: Full Scan Mapped Drives should be disabled for performance. See https://maester.dev/docs/tests/MDE.AV08" -Tag "MDE.AV08" {
        $result = Test-MtMdeMappedDriveScanning
        if ($null -ne $result) {
            $result | Should -Be $true -Because "full scan of mapped drives should be disabled for performance optimization"
        }
    }

    It "MDE.AV09: Scanning Network Files should be enabled. See https://maester.dev/docs/tests/MDE.AV09" -Tag "MDE.AV09" {
        $result = Test-MtMdeNetworkFileScanning
        if ($null -ne $result) {
            $result | Should -Be $true -Because "scanning network files should be enabled for comprehensive protection"
        }
    }

    It "MDE.AV10: CPU Load Factor should be optimized (20-30%). See https://maester.dev/docs/tests/MDE.AV10" -Tag "MDE.AV10" {
        $result = Test-MtMdeCpuLoadFactor
        if ($null -ne $result) {
            $result | Should -Be $true -Because "CPU load should be balanced between performance and security"
        }
    }

    It "MDE.AV11: Scan should be scheduled. See https://maester.dev/docs/tests/MDE.AV11" -Tag "MDE.AV11" {
        $result = Test-MtMdeScheduleScanDay
        if ($null -ne $result) {
            $result | Should -Be $true -Because "scans should be scheduled for comprehensive coverage"
        }
    }

    It "MDE.AV12: Quick Scan Time configuration is not required. See https://maester.dev/docs/tests/MDE.AV12" -Tag "MDE.AV12" {
        $result = Test-MtMdeQuickScanTime
        if ($null -ne $result) {
            $result | Should -Be $true -Because "quick scan time configuration is not required"
        }
    }

    It "MDE.AV13: Signatures should be checked before scan. See https://maester.dev/docs/tests/MDE.AV13" -Tag "MDE.AV13" {
        $result = Test-MtMdeSignatureBeforeScan
        if ($null -ne $result) {
            $result | Should -Be $true -Because "signatures should be checked before scan for zero-day protection"
        }
    }

    It "MDE.AV14: Cloud Block Level should be High or higher. See https://maester.dev/docs/tests/MDE.AV14" -Tag "MDE.AV14" {
        $result = Test-MtMdeCloudBlockLevel
        if ($null -ne $result) {
            $result | Should -Be $true -Because "cloud block level should be High or higher for maximum protection"
        }
    }

    It "MDE.AV15: Cloud Extended Timeout should be 30-50 seconds. See https://maester.dev/docs/tests/MDE.AV15" -Tag "MDE.AV15" {
        $result = Test-MtMdeCloudExtendedTimeout
        if ($null -ne $result) {
            $result | Should -Be $true -Because "cloud extended timeout should be 30-50 seconds for optimal detection"
        }
    }

    It "MDE.AV16: Signature Update Interval should be 1-4 hours. See https://maester.dev/docs/tests/MDE.AV16" -Tag "MDE.AV16" {
        $result = Test-MtMdeSignatureUpdateInterval
        if ($null -ne $result) {
            $result | Should -Be $true -Because "signature update interval should be 1-4 hours for current protection"
        }
    }

    It "MDE.AV17: PUA Protection should be enabled. See https://maester.dev/docs/tests/MDE.AV17" -Tag "MDE.AV17" {
        $result = Test-MtMdePuaProtection
        if ($null -ne $result) {
            $result | Should -Be $true -Because "PUA protection should be enabled to block potentially unwanted applications"
        }
    }

    It "MDE.AV18: Network Protection should be enabled. See https://maester.dev/docs/tests/MDE.AV18" -Tag "MDE.AV18" {
        $result = Test-MtMdeNetworkProtection
        if ($null -ne $result) {
            $result | Should -Be $true -Because "network protection should be enabled to block web-based threats"
        }
    }

    It "MDE.AV19: Local Admin Merge should be disabled. See https://maester.dev/docs/tests/MDE.AV19" -Tag "MDE.AV19" {
        $result = Test-MtMdeDisableLocalAdminMerge
        if ($null -ne $result) {
            $result | Should -Be $true -Because "local admin merge should be disabled to prevent local exclusions"
        }
    }

    It "MDE.AV20: Tamper Protection should be enabled tenant-wide. See https://maester.dev/docs/tests/MDE.AV20" -Tag "MDE.AV20" {
        $result = Test-MtMdeTamperProtection
        if ($null -ne $result) {
            $result | Should -Be $true -Because "tamper protection should be enabled tenant-wide"
        }
    }

    It "MDE.AV21: Real-Time Scan Direction should cover both directions. See https://maester.dev/docs/tests/MDE.AV21" -Tag "MDE.AV21" {
        $result = Test-MtMdeRealtimeScanDirection
        if ($null -ne $result) {
            $result | Should -Be $true -Because "real-time scan should monitor both incoming and outgoing traffic"
        }
    }

    It "MDE.AV22: Cleaned Malware should be retained for at least 30 days. See https://maester.dev/docs/tests/MDE.AV22" -Tag "MDE.AV22" {
        $result = Test-MtMdeRetainCleanedMalware
        if ($null -ne $result) {
            $result | Should -Be $true -Because "cleaned malware should be retained for forensic analysis"
        }
    }

    It "MDE.AV23: Catch-up Full Scan should be disabled. See https://maester.dev/docs/tests/MDE.AV23" -Tag "MDE.AV23" {
        $result = Test-MtMdeCatchupFullScan
        if ($null -ne $result) {
            $result | Should -Be $true -Because "catch-up full scan should be disabled to avoid additional system load"
        }
    }

    It "MDE.AV24: Catch-up Quick Scan should be disabled. See https://maester.dev/docs/tests/MDE.AV24" -Tag "MDE.AV24" {
        $result = Test-MtMdeCatchupQuickScan
        if ($null -ne $result) {
            $result | Should -Be $true -Because "catch-up quick scan should be disabled"
        }
    }

    It "MDE.AV25: Remediation Action should be set to Quarantine. See https://maester.dev/docs/tests/MDE.AV25" -Tag "MDE.AV25" {
        $result = Test-MtMdeRemediationAction
        if ($null -ne $result) {
            $result | Should -Be $true -Because "remediation action should be set to quarantine for all threat levels"
        }
    }

    It "MDE.AV26: Sample Submission should send safe samples automatically. See https://maester.dev/docs/tests/MDE.AV26" -Tag "MDE.AV26" {
        $result = Test-MtMdeSubmitSamplesConsent
        if ($null -ne $result) {
            $result | Should -Be $true -Because "sample submission should be configured to send safe samples automatically"
        }
    }
}
