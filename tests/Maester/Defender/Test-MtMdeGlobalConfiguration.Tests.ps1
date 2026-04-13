Describe "MDE" -Tag "Maester", "MDE", "MDE-GlobalConfig", "Defender", "Security", "All" {
    It "MDE.GC01: Preview Features should be enabled organization-wide. See https://maester.dev/docs/tests/MDE.GC01" -Tag "MDE.GC01" {
        $result = Test-MtMdePreviewFeatures
        if ($null -ne $result) {
            $result | Should -Be $true -Because "preview features should be enabled organization-wide"
        }
    }

    It "MDE.GC02: Tamper Protection should be enabled tenant-wide. See https://maester.dev/docs/tests/MDE.GC02" -Tag "MDE.GC02" {
        $result = Test-MtMdeGcTamperProtection
        if ($null -ne $result) {
            $result | Should -Be $true -Because "tamper protection should be enabled tenant-wide"
        }
    }

    It "MDE.GC03: EDR in Block Mode should be enabled for Defender AV devices. See https://maester.dev/docs/tests/MDE.GC03" -Tag "MDE.GC03" {
        $result = Test-MtMdeEdrBlockMode
        if ($null -ne $result) {
            $result | Should -Be $true -Because "EDR in block mode should be enabled for Defender AV devices"
        }
    }

    It "MDE.GC04: Automatically Resolve Alerts should be configured. See https://maester.dev/docs/tests/MDE.GC04" -Tag "MDE.GC04" {
        $result = Test-MtMdeAutoResolveAlerts
        if ($null -ne $result) {
            $result | Should -Be $true -Because "automatically resolve alerts should be configured"
        }
    }

    It "MDE.GC05: Allow or Block File capability should be enabled. See https://maester.dev/docs/tests/MDE.GC05" -Tag "MDE.GC05" {
        $result = Test-MtMdeAllowBlockFile
        if ($null -ne $result) {
            $result | Should -Be $true -Because "allow or block file capability should be enabled"
        }
    }

    It "MDE.GC06: Hide Duplicate Device Records should be enabled. See https://maester.dev/docs/tests/MDE.GC06" -Tag "MDE.GC06" {
        $result = Test-MtMdeHideDuplicateDevices
        if ($null -ne $result) {
            $result | Should -Be $true -Because "hide duplicate device records should be enabled"
        }
    }

    It "MDE.GC07: Custom Network Indicators should be enabled. See https://maester.dev/docs/tests/MDE.GC07" -Tag "MDE.GC07" {
        $result = Test-MtMdeCustomNetworkIndicators
        if ($null -ne $result) {
            $result | Should -Be $true -Because "custom network indicators should be enabled"
        }
    }

    It "MDE.GC08: Web Content Filtering should be enabled (requires P2 license). See https://maester.dev/docs/tests/MDE.GC08" -Tag "MDE.GC08" {
        $result = Test-MtMdeWebContentFiltering
        if ($null -ne $result) {
            $result | Should -Be $true -Because "web content filtering should be enabled (requires P2 license)"
        }
    }

    It "MDE.GC09: Device Discovery should be enabled for Shadow IT visibility. See https://maester.dev/docs/tests/MDE.GC09" -Tag "MDE.GC09" {
        $result = Test-MtMdeDeviceDiscovery
        if ($null -ne $result) {
            $result | Should -Be $true -Because "device discovery should be enabled for Shadow IT visibility"
        }
    }

    It "MDE.GC10: Download Quarantined Files should be enabled for forensics. See https://maester.dev/docs/tests/MDE.GC10" -Tag "MDE.GC10" {
        $result = Test-MtMdeDownloadQuarantinedFiles
        if ($null -ne $result) {
            $result | Should -Be $true -Because "download quarantined files should be enabled for forensics"
        }
    }

    It "MDE.GC11: Streamlined Connectivity should be enabled (default). See https://maester.dev/docs/tests/MDE.GC11" -Tag "MDE.GC11" {
        $result = Test-MtMdeStreamlinedConnectivity
        if ($null -ne $result) {
            $result | Should -Be $true -Because "streamlined connectivity should be enabled (default)"
        }
    }

    It "MDE.GC12: Apply Streamlined Connectivity to Intune/DFC should be enabled. See https://maester.dev/docs/tests/MDE.GC12" -Tag "MDE.GC12" {
        $result = Test-MtMdeStreamlinedConnectivityIntune
        if ($null -ne $result) {
            $result | Should -Be $true -Because "streamlined connectivity to Intune/DFC should be enabled"
        }
    }

    It "MDE.GC13: Isolation Exclusion Rules should be disabled unless required. See https://maester.dev/docs/tests/MDE.GC13" -Tag "MDE.GC13" {
        $result = Test-MtMdeIsolationExclusions
        if ($null -ne $result) {
            $result | Should -Be $true -Because "isolation exclusion rules should be disabled unless required"
        }
    }

    It "MDE.GC14: Deception capabilities should be evaluated (optional honeypots). See https://maester.dev/docs/tests/MDE.GC14" -Tag "MDE.GC14" {
        $result = Test-MtMdeDeceptionCapabilities
        if ($null -ne $result) {
            $result | Should -Be $true -Because "deception capabilities should be evaluated (optional honeypots)"
        }
    }

    It "MDE.GC15: Microsoft Intune Connection should be enabled as MDM prerequisite. See https://maester.dev/docs/tests/MDE.GC15" -Tag "MDE.GC15" {
        $result = Test-MtMdeIntuneConnection
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Microsoft Intune connection should be enabled as MDM prerequisite"
        }
    }

    It "MDE.GC16: Authenticated Telemetry should be reviewed for privacy compliance. See https://maester.dev/docs/tests/MDE.GC16" -Tag "MDE.GC16" {
        $result = Test-MtMdeAuthenticatedTelemetry
        if ($null -ne $result) {
            $result | Should -Be $true -Because "authenticated telemetry should be reviewed for privacy compliance"
        }
    }
}
