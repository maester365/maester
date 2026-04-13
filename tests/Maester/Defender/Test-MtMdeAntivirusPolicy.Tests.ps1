Describe "MDE" -Tag "Maester", "MDE", "Defender", "Security", "All" {
    It "MT.1123: Archive Scanning should be enabled. See https://maester.dev/docs/tests/MT.1123" -Tag "MT.1123", "MDE" {
        $result = Test-MtMdeArchiveScanning
        if ($null -ne $result) {
            $result | Should -Be $true -Because "archive scanning helps detect malware in compressed files"
        }
    }

    It "MT.1124: Behavior Monitoring should be enabled. See https://maester.dev/docs/tests/MT.1124" -Tag "MT.1124", "MDE" {
        $result = Test-MtMdeBehaviorMonitoring
        if ($null -ne $result) {
            $result | Should -Be $true -Because "behavior monitoring is essential for detecting advanced threats"
        }
    }

    It "MT.1125: Cloud Protection should be enabled. See https://maester.dev/docs/tests/MT.1125" -Tag "MT.1125", "MDE" {
        $result = Test-MtMdeCloudProtection
        if ($null -ne $result) {
            $result | Should -Be $true -Because "cloud protection provides real-time threat intelligence"
        }
    }

    It "MT.1126: Email Scanning should be enabled. See https://maester.dev/docs/tests/MT.1126" -Tag "MT.1126", "MDE" {
        $result = Test-MtMdeEmailScanning
        if ($null -ne $result) {
            $result | Should -Be $true -Because "email scanning should be enabled to protect Exchange queues"
        }
    }

    It "MT.1127: Script Scanning should be enabled. See https://maester.dev/docs/tests/MT.1127" -Tag "MT.1127", "MDE" {
        $result = Test-MtMdeScriptScanning
        if ($null -ne $result) {
            $result | Should -Be $true -Because "script scanning should be enabled to block malicious scripts"
        }
    }

    It "MT.1128: Real-time Monitoring should be enabled. See https://maester.dev/docs/tests/MT.1128" -Tag "MT.1128", "MDE" {
        $result = Test-MtMdeRealtimeMonitoring
        if ($null -ne $result) {
            $result | Should -Be $true -Because "real-time monitoring provides essential protection against live threats"
        }
    }

    It "MT.1129: Full Scan Removable Drives should be enabled. See https://maester.dev/docs/tests/MT.1129" -Tag "MT.1129", "MDE" {
        $result = Test-MtMdeRemovableDriveScanning
        if ($null -ne $result) {
            $result | Should -Be $true -Because "full scan of removable drives should be enabled to mitigate USB risks"
        }
    }

    It "MT.1130: Full Scan Mapped Drives should be disabled for performance. See https://maester.dev/docs/tests/MT.1130" -Tag "MT.1130", "MDE" {
        $result = Test-MtMdeMappedDriveScanning
        if ($null -ne $result) {
            $result | Should -Be $true -Because "full scan of mapped drives should be disabled for performance optimization"
        }
    }

    It "MT.1131: Scanning Network Files should be enabled. See https://maester.dev/docs/tests/MT.1131" -Tag "MT.1131", "MDE" {
        $result = Test-MtMdeNetworkFileScanning
        if ($null -ne $result) {
            $result | Should -Be $true -Because "scanning network files should be enabled for comprehensive protection"
        }
    }

    It "MT.1132: CPU Load Factor should be optimized (20-30%). See https://maester.dev/docs/tests/MT.1132" -Tag "MT.1132", "MDE" {
        $result = Test-MtMdeCpuLoadFactor
        if ($null -ne $result) {
            $result | Should -Be $true -Because "CPU load should be balanced between performance and security"
        }
    }

    It "MT.1133: Scan should be scheduled. See https://maester.dev/docs/tests/MT.1133" -Tag "MT.1133", "MDE" {
        $result = Test-MtMdeScheduleScanDay
        if ($null -ne $result) {
            $result | Should -Be $true -Because "scans should be scheduled for comprehensive coverage"
        }
    }

    It "MT.1134: Quick Scan Time configuration is not required. See https://maester.dev/docs/tests/MT.1134" -Tag "MT.1134", "MDE" {
        $result = Test-MtMdeQuickScanTime
        if ($null -ne $result) {
            $result | Should -Be $true -Because "quick scan time configuration is not required"
        }
    }

    It "MT.1135: Signatures should be checked before scan. See https://maester.dev/docs/tests/MT.1135" -Tag "MT.1135", "MDE" {
        $result = Test-MtMdeSignatureBeforeScan
        if ($null -ne $result) {
            $result | Should -Be $true -Because "signatures should be checked before scan for zero-day protection"
        }
    }

    It "MT.1136: Cloud Block Level should be High or higher. See https://maester.dev/docs/tests/MT.1136" -Tag "MT.1136", "MDE" {
        $result = Test-MtMdeCloudBlockLevel
        if ($null -ne $result) {
            $result | Should -Be $true -Because "cloud block level should be High or higher for maximum protection"
        }
    }

    It "MT.1137: Cloud Extended Timeout should be 30-50 seconds. See https://maester.dev/docs/tests/MT.1137" -Tag "MT.1137", "MDE" {
        $result = Test-MtMdeCloudExtendedTimeout
        if ($null -ne $result) {
            $result | Should -Be $true -Because "cloud extended timeout should be 30-50 seconds for optimal detection"
        }
    }

    It "MT.1138: Signature Update Interval should be 1-4 hours. See https://maester.dev/docs/tests/MT.1138" -Tag "MT.1138", "MDE" {
        $result = Test-MtMdeSignatureUpdateInterval
        if ($null -ne $result) {
            $result | Should -Be $true -Because "signature update interval should be 1-4 hours for current protection"
        }
    }

    It "MT.1139: PUA Protection should be enabled. See https://maester.dev/docs/tests/MT.1139" -Tag "MT.1139", "MDE" {
        $result = Test-MtMdePuaProtection
        if ($null -ne $result) {
            $result | Should -Be $true -Because "PUA protection should be enabled to block potentially unwanted applications"
        }
    }

    It "MT.1140: Network Protection should be enabled. See https://maester.dev/docs/tests/MT.1140" -Tag "MT.1140", "MDE" {
        $result = Test-MtMdeNetworkProtection
        if ($null -ne $result) {
            $result | Should -Be $true -Because "network protection should be enabled to block web-based threats"
        }
    }

    It "MT.1141: Local Admin Merge should be disabled. See https://maester.dev/docs/tests/MT.1141" -Tag "MT.1141", "MDE" {
        $result = Test-MtMdeDisableLocalAdminMerge
        if ($null -ne $result) {
            $result | Should -Be $true -Because "local admin merge should be disabled to prevent local exclusions"
        }
    }

    It "MT.1142: Real-Time Scan Direction should cover both directions. See https://maester.dev/docs/tests/MT.1142" -Tag "MT.1142", "MDE" {
        $result = Test-MtMdeRealtimeScanDirection
        if ($null -ne $result) {
            $result | Should -Be $true -Because "real-time scan should monitor both incoming and outgoing traffic"
        }
    }

    It "MT.1143: Cleaned Malware should be retained for at least 30 days. See https://maester.dev/docs/tests/MT.1143" -Tag "MT.1143", "MDE" {
        $result = Test-MtMdeRetainCleanedMalware
        if ($null -ne $result) {
            $result | Should -Be $true -Because "cleaned malware should be retained for forensic analysis"
        }
    }

    It "MT.1144: Catch-up Full Scan should be disabled. See https://maester.dev/docs/tests/MT.1144" -Tag "MT.1144", "MDE" {
        $result = Test-MtMdeCatchupFullScan
        if ($null -ne $result) {
            $result | Should -Be $true -Because "catch-up full scan should be disabled to avoid additional system load"
        }
    }

    It "MT.1145: Catch-up Quick Scan should be disabled. See https://maester.dev/docs/tests/MT.1145" -Tag "MT.1145", "MDE" {
        $result = Test-MtMdeCatchupQuickScan
        if ($null -ne $result) {
            $result | Should -Be $true -Because "catch-up quick scan should be disabled"
        }
    }

    It "MT.1146: Sample Submission should send safe samples automatically. See https://maester.dev/docs/tests/MT.1146" -Tag "MT.1146", "MDE" {
        $result = Test-MtMdeSubmitSamplesConsent
        if ($null -ne $result) {
            $result | Should -Be $true -Because "sample submission should be configured to send safe samples automatically"
        }
    }
}
