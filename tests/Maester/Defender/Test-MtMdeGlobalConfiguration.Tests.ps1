Describe "Microsoft Defender for Endpoint - Global Configuration" -Tag "Maester", "MDE", "Security", "All", "MDE-GlobalConfig", "ManualReview" {

    # Global Configuration Tests (MDE.GC01 to MDE.GC16) - Using Unified Test Engine
    It "MDE.GC01: Preview Features should be enabled organization-wide. See https://maester.dev/docs/tests/MDE.GC01" -Tag "MDE.GC01", "ManualReview" {
        <#
            Verify that Preview Features are enabled organization-wide in Microsoft Defender XDR.
            Category: Global Config | Severity: Low 🟢

            Manual Review Required:
            - Check Preview Features setting in Microsoft Defender XDR portal
            - Navigate to Settings → Microsoft Defender XDR → Preview Features
            - Verify organization-wide activation
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC01" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "preview features should be enabled organization-wide"
            }
        }
    }

    It "MDE.GC02: Tamper Protection should be enabled tenant-wide. See https://maester.dev/docs/tests/MDE.GC02" -Tag "MDE.GC02", "ManualReview" {
        <#
            Verify that Tamper Protection is enabled tenant-wide in Advanced Features.
            Category: Global Config | Severity: High 🟠

            Manual Review Required:
            - Check Tamper Protection setting in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Verify tenant-wide activation
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC02" -TestName $____Pester.CurrentTest.ExpandedName
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

    It "MDE.GC03: EDR in Block Mode should be enabled for Defender AV devices. See https://maester.dev/docs/tests/MDE.GC03" -Tag "MDE.GC03", "ManualReview" {
        <#
            Verify that EDR in Block Mode is enabled for Microsoft Defender Antivirus devices.
            Category: Global Config | Severity: High 🟠

            Manual Review Required:
            - Check EDR in Block Mode setting in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Verify activation for Defender AV devices only
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC03" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "EDR in block mode should be enabled for Defender AV devices"
            }
        }
    }

    It "MDE.GC04: Automatically Resolve Alerts should be configured. See https://maester.dev/docs/tests/MDE.GC04" -Tag "MDE.GC04", "ManualReview" {
        <#
            Verify that Automatically Resolve Alerts is properly configured.
            Category: Global Config | Severity: Medium 🟡

            Manual Review Required:
            - Check auto-resolution settings in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Verify auto-resolution is active for appropriate alert types
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC04" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "automatically resolve alerts should be configured"
            }
        }
    }

    It "MDE.GC05: Allow or Block File capability should be enabled. See https://maester.dev/docs/tests/MDE.GC05" -Tag "MDE.GC05", "ManualReview" {
        <#
            Verify that Allow or Block File capability is enabled for IOC handling.
            Category: Global Config | Severity: Medium 🟡

            Manual Review Required:
            - Check Allow or Block File setting in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Verify IOC handling capabilities are enabled
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC05" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "allow or block file capability should be enabled"
            }
        }
    }

    It "MDE.GC06: Hide Duplicate Device Records should be enabled. See https://maester.dev/docs/tests/MDE.GC06" -Tag "MDE.GC06", "ManualReview" {
        <#
            Verify that Hide Duplicate Device Records is enabled to reduce clutter.
            Category: Global Config | Severity: Low 🟢

            Manual Review Required:
            - Check duplicate device handling in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Verify duplicate records are hidden to avoid clutter
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC06" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "hide duplicate device records should be enabled"
            }
        }
    }

    It "MDE.GC07: Custom Network Indicators should be enabled. See https://maester.dev/docs/tests/MDE.GC07" -Tag "MDE.GC07", "ManualReview" {
        <#
            Verify that Custom Network Indicators are enabled for IOC management.
            Category: Global Config | Severity: High 🟠

            Manual Review Required:
            - Check Custom Network Indicators in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Verify IOC list management capabilities are enabled
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC07" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "custom network indicators should be enabled"
            }
        }
    }

    It "MDE.GC08: Web Content Filtering should be enabled (requires P2 license). See https://maester.dev/docs/tests/MDE.GC08" -Tag "MDE.GC08", "ManualReview" {
        <#
            Verify that Web Content Filtering is enabled (requires Defender for Endpoint P2 license).
            Category: Global Config | Severity: High 🟠

            Manual Review Required:
            - Check Web Content Filtering in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Verify P2 license is available and feature is enabled
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC08" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "web content filtering should be enabled (requires P2 license)"
            }
        }
    }

    It "MDE.GC09: Device Discovery should be enabled for Shadow IT visibility. See https://maester.dev/docs/tests/MDE.GC09" -Tag "MDE.GC09", "ManualReview" {
        <#
            Verify that Device Discovery is enabled for Shadow IT visibility.
            Category: Global Config | Severity: Medium 🟡

            Manual Review Required:
            - Check Device Discovery settings in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Verify Shadow IT visibility capabilities are enabled
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC09" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "device discovery should be enabled for Shadow IT visibility"
            }
        }
    }

    It "MDE.GC10: Download Quarantined Files should be enabled for forensics. See https://maester.dev/docs/tests/MDE.GC10" -Tag "MDE.GC10", "ManualReview" {
        <#
            Verify that Download Quarantined Files capability is enabled for forensic analysis.
            Category: Global Config | Severity: Medium 🟡

            Manual Review Required:
            - Check quarantined file download in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Verify forensic capabilities are enabled
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC10" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "download quarantined files should be enabled for forensics"
            }
        }
    }

    It "MDE.GC11: Streamlined Connectivity should be enabled (default). See https://maester.dev/docs/tests/MDE.GC11" -Tag "MDE.GC11", "ManualReview" {
        <#
            Verify that Streamlined Connectivity is enabled as default configuration.
            Category: Global Config | Severity: Medium 🟡

            Manual Review Required:
            - Check Streamlined Connectivity in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Verify default connectivity settings are properly configured
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC11" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "streamlined connectivity should be enabled (default)"
            }
        }
    }

    It "MDE.GC12: Apply Streamlined Connectivity to Intune/DFC should be enabled. See https://maester.dev/docs/tests/MDE.GC12" -Tag "MDE.GC12", "ManualReview" {
        <#
            Verify that Streamlined Connectivity is applied to Intune/DFC for synchronization.
            Category: Global Config | Severity: Medium 🟡

            Manual Review Required:
            - Check Intune integration settings in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Verify Intune-sync connectivity is properly configured
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC12" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "streamlined connectivity to Intune/DFC should be enabled"
            }
        }
    }

    It "MDE.GC13: Isolation Exclusion Rules should be disabled unless required. See https://maester.dev/docs/tests/MDE.GC13" -Tag "MDE.GC13", "ManualReview" {
        <#
            Verify that Isolation Exclusion Rules are disabled unless specifically required.
            Category: Global Config | Severity: High 🟠

            Manual Review Required:
            - Check Isolation Exclusion Rules in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Verify rules are disabled unless business justification exists
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC13" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "isolation exclusion rules should be disabled unless required"
            }
        }
    }

    It "MDE.GC14: Deception capabilities should be evaluated (optional honeypots). See https://maester.dev/docs/tests/MDE.GC14" -Tag "MDE.GC14", "ManualReview" {
        <#
            Verify that Deception capabilities are properly evaluated (optional honeypot deployment).
            Category: Global Config | Severity: Low 🟢

            Manual Review Required:
            - Check Deception settings in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Evaluate if honeypot deployment aligns with security strategy
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC14" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "deception capabilities should be evaluated (optional honeypots)"
            }
        }
    }

    It "MDE.GC15: Microsoft Intune Connection should be enabled as MDM prerequisite. See https://maester.dev/docs/tests/MDE.GC15" -Tag "MDE.GC15", "ManualReview" {
        <#
            Verify that Microsoft Intune Connection is enabled as prerequisite for MDM integration.
            Category: Global Config | Severity: Medium 🟡

            Manual Review Required:
            - Check Microsoft Intune Connection in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Verify MDM integration prerequisites are met
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC15" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "Microsoft Intune connection should be enabled as MDM prerequisite"
            }
        }
    }

    It "MDE.GC16: Authenticated Telemetry should be reviewed for privacy compliance. See https://maester.dev/docs/tests/MDE.GC16" -Tag "MDE.GC16", "ManualReview" {
        <#
            Verify that Authenticated Telemetry settings comply with privacy requirements.
            Category: Global Config | Severity: Low 🟢

            Manual Review Required:
            - Check Authenticated Telemetry in Microsoft Defender XDR portal
            - Navigate to Settings → Endpoints → Advanced Features
            - Review privacy and data protection compliance
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.GC16" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "authenticated telemetry should be reviewed for privacy compliance"
            }
        }
    }
}