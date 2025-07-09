<#
.SYNOPSIS
    Gets configuration settings for Microsoft Defender for Endpoint tests

.DESCRIPTION
    Returns test configuration for MDE tests including settings, expected values,
    and test metadata. Supports Antivirus, Global Config, and Policy Design tests.

.PARAMETER TestId
    The MDE test identifier (e.g., "MDE.AV01", "MDE.GC01", "MDE.PD01")

.EXAMPLE
    Get-MtMdeUnifiedConfiguration -TestId "MDE.AV01"

    Gets configuration for the Archive Scanning test

.EXAMPLE
    Get-MtMdeUnifiedConfiguration

    Returns all available MDE test configurations
#>

#region Unified MDE Configuration
function Get-MtMdeUnifiedConfiguration {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TestId
    )

    $mdeConfig = Get-MtMdeConfig
    $configurations = @{}

    # Helper function to create standardized test configuration
    function New-MdeTestConfig {
        param(
            [string]$TestId,
            [string]$SettingName,
            [string]$Category,
            [string]$Severity,
            [string]$TestType,
            [string]$Description,
            [string]$SecurityImpact,
            [array]$ActionSteps,
            [hashtable]$ComplianceParameters = @{},
            [hashtable]$TestSpecificData = @{}
        )

        $config = @{
            # Standard properties for all tests
            TestId = $TestId
            SettingName = $SettingName
            Category = $Category
            Severity = $Severity
            TestType = $TestType
            Description = $Description
            SecurityImpact = $SecurityImpact
            ActionSteps = $ActionSteps

            # Compliance parameters (unified structure)
            ComplianceParameters = $ComplianceParameters

            # Test-specific data (flexible for different test types)
            TestSpecificData = $TestSpecificData

            # Applied from global config
            ComplianceLogic = "AllPolicies"  # Will be overridden below
        }

        return $config
    }

    # Antivirus Policy Tests (MDE.AV01-MDE.AV26)
    $configurations["MDE.AV01"] = New-MdeTestConfig -TestId "MDE.AV01" -SettingName "Archive Scanning" -Category "Scan Engines" -Severity "Medium" -TestType "Automated" -Description "Verify that archive scanning is enabled to detect malware in compressed files." -SecurityImpact "Disabled archive scanning allows malware to hide in compressed files (ZIP, RAR, etc.)" -ActionSteps @("Enable **Allow Archive Scanning**") -ComplianceParameters @{
        ComplianceCheck = "Boolean"
        ExpectedValue = "_1"
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_allowarchivescanning"
    }

    $configurations["MDE.AV02"] = New-MdeTestConfig -TestId "MDE.AV02" -SettingName "Behavior Monitoring" -Category "Scan Engines" -Severity "High" -TestType "Automated" -Description "Verify that behavior monitoring is enabled - prerequisite for EDR capabilities." -SecurityImpact "Disabled behavior monitoring reduces ability to detect zero-day threats and advanced persistent threats (APTs)" -ActionSteps @("Enable **Allow Behavior Monitoring**") -ComplianceParameters @{
        ComplianceCheck = "Boolean"
        ExpectedValue = "_1"
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_allowbehaviormonitoring"
    }

    $configurations["MDE.AV03"] = New-MdeTestConfig -TestId "MDE.AV03" -SettingName "Cloud Protection" -Category "Scan Engines" -Severity "High" -TestType "Automated" -Description "Verify that cloud protection is enabled with CloudLevel ≥ High." -SecurityImpact "Disabled cloud protection reduces real-time threat detection and response capabilities" -ActionSteps @("Enable **Allow Cloud Protection**") -ComplianceParameters @{
        ComplianceCheck = "Boolean"
        ExpectedValue = "_1"
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_allowcloudprotection"
    }

    $configurations["MDE.AV04"] = New-MdeTestConfig -TestId "MDE.AV04" -SettingName "Email Scanning" -Category "Scan Engines" -Severity "Medium" -TestType "Automated" -Description "Verify that email scanning is enabled for Exchange queues protection." -SecurityImpact "Disabled email scanning allows malware to enter through Exchange message queues" -ActionSteps @("Enable **Allow Email Scanning**") -ComplianceParameters @{
        ComplianceCheck = "Boolean"
        ExpectedValue = "_1"
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_allowemailscanning"
    }

    $configurations["MDE.AV05"] = New-MdeTestConfig -TestId "MDE.AV05" -SettingName "Script Scanning" -Category "Scan Engines" -Severity "High" -TestType "Automated" -Description "Verify that script scanning is enabled to block malicious JavaScript." -SecurityImpact "Disabled script scanning allows malicious PowerShell, JavaScript, and VBScript execution" -ActionSteps @("Enable **Allow Script Scanning**") -ComplianceParameters @{
        ComplianceCheck = "Boolean"
        ExpectedValue = "_1"
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_allowscriptscanning"
    }

    $configurations["MDE.AV06"] = New-MdeTestConfig -TestId "MDE.AV06" -SettingName "Real-time Monitoring" -Category "Scan Engines" -Severity "High" -TestType "Automated" -Description "Verify that realtime monitoring is enabled - core protection function." -SecurityImpact "Disabled real-time monitoring allows malware to execute without immediate detection" -ActionSteps @("Enable **Allow Real-time Monitoring**") -ComplianceParameters @{
        ComplianceCheck = "Boolean"
        ExpectedValue = "_1"
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_allowrealtimemonitoring"
    }

    $configurations["MDE.AV07"] = New-MdeTestConfig -TestId "MDE.AV07" -SettingName "Allow Full Scan Removable Drives" -Category "Scan Configuration" -Severity "Medium" -TestType "Automated" -Description "Verify that full scan of removable drives is enabled to mitigate USB risks." -SecurityImpact "Disabled removable drive scanning allows USB-based malware infections" -ActionSteps @("Enable **Allow Full Scan on Removable Drives**") -ComplianceParameters @{
        ComplianceCheck = "Boolean"
        ExpectedValue = "_1"
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_allowfullscanremovabledrivescanning"
    }

    $configurations["MDE.AV08"] = New-MdeTestConfig -TestId "MDE.AV08" -SettingName "Allow Full Scan Mapped Drives" -Category "Scan Configuration" -Severity "Low" -TestType "Automated" -Description "Verify that full scan of mapped network drives is disabled for performance reasons." -SecurityImpact "Full scan on mapped drives can cause performance issues" -ActionSteps @("Disable **Allow Full Scan on Mapped Network Drives** for performance") -ComplianceParameters @{
        ComplianceCheck = "Boolean"
        ExpectedValue = "_0"
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_allowfullscanonmappednetworkdrives"
    }

    $configurations["MDE.AV09"] = New-MdeTestConfig -TestId "MDE.AV09" -SettingName "Network File Scanning" -Category "Scan Configuration" -Severity "Medium" -TestType "Automated" -Description "Verify that scanning network files is enabled despite SMB load considerations." -SecurityImpact "Disabled network file scanning creates attack vectors through shared files" -ActionSteps @("Enable **Allow Scanning Network Files**") -ComplianceParameters @{
        ComplianceCheck = "Boolean"
        ExpectedValue = "_1"
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_allowscanningnetworkfiles"
    }

    $configurations["MDE.AV10"] = New-MdeTestConfig -TestId "MDE.AV10" -SettingName "Avg CPU Load Factor" -Category "Performance" -Severity "Low" -TestType "Automated" -Description "Verify that average CPU load factor is configured between 20-30%." -SecurityImpact "Inappropriate CPU load settings may impact system performance or scan effectiveness" -ActionSteps @("Set **Average CPU Load Factor** to 20-30%") -ComplianceParameters @{
        ComplianceCheck = "Range"
        ExpectedValue = 25
        RangeMin = 20
        RangeMax = 30
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_avgcpuloadfactor"
    }

    $configurations["MDE.AV11"] = New-MdeTestConfig -TestId "MDE.AV11" -SettingName "Schedule Scan Day" -Category "Scheduled Scans" -Severity "Medium" -TestType "Automated" -Description "Verify that scans are scheduled for every day during off-hours." -SecurityImpact "Irregular scan schedule may miss persistent threats" -ActionSteps @("Configure **Schedule Scan Day** for daily scanning") -ComplianceParameters @{
        ComplianceCheck = "Enum"
        ExpectedValue = "_0"
        ValidValues = @("_0", "_1", "_2", "_3", "_4", "_5", "_6", "_7")
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_schedulescanday"
    }

    $configurations["MDE.AV12"] = New-MdeTestConfig -TestId "MDE.AV12" -SettingName "Schedule Quick Scan Time" -Category "Scheduled Scans" -Severity "Low" -TestType "Automated" -Description "Verify that quick scan time is not configured (not required)." -SecurityImpact "Not required - Quick scans are replaced by real-time protection" -ActionSteps @("No action needed - Quick scan timing not required") -ComplianceParameters @{
        ComplianceCheck = "NotRequired"
        ExpectedValue = $null
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_schedulequickscantime"
    }

    $configurations["MDE.AV13"] = New-MdeTestConfig -TestId "MDE.AV13" -SettingName "Check Signatures Before Scan" -Category "Signatur & Cloud" -Severity "High" -TestType "Automated" -Description "Verify that signature checking before scan is enabled for zero-day protection." -SecurityImpact "Scans with outdated signatures may miss recent threats and zero-day attacks" -ActionSteps @("Enable **Check for Signatures Before Running Scan**") -ComplianceParameters @{
        ComplianceCheck = "Boolean"
        ExpectedValue = "_1"
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_checkforsignaturesbeforerunningscan"
    }

    $configurations["MDE.AV14"] = New-MdeTestConfig -TestId "MDE.AV14" -SettingName "Cloud Block Level" -Category "Signatur & Cloud" -Severity "High" -TestType "Automated" -Description "Verify that cloud block level is set to High, High+, or Zero Tolerance." -SecurityImpact "Low cloud block level reduces proactive threat blocking capabilities" -ActionSteps @("Set **Cloud Block Level** to High, High Plus, or Zero Tolerance") -ComplianceParameters @{
        ComplianceCheck = "MinimumLevel"
        ExpectedValue = "_2"
        MinimumValue = 2
        ValidLevels = @{
            "_0" = 0  # Default
            "_2" = 2  # High
            "_4" = 4  # High Plus
            "_6" = 6  # Zero Tolerance
        }
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_cloudblocklevel"
    }

    $configurations["MDE.AV15"] = New-MdeTestConfig -TestId "MDE.AV15" -SettingName "Cloud Extended Timeout" -Category "Signatur & Cloud" -Severity "Medium" -TestType "Automated" -Description "Verify that cloud extended timeout is configured between 30-50 seconds (UX vs Detection balance)." -SecurityImpact "Insufficient cloud timeout may prevent thorough analysis vs UX impact" -ActionSteps @("Set **Cloud Extended Timeout** to 30-50 seconds") -ComplianceParameters @{
        ComplianceCheck = "Range"
        ExpectedValue = 40
        RangeMin = 30
        RangeMax = 50
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_cloudextendedtimeout"
    }

    $configurations["MDE.AV16"] = New-MdeTestConfig -TestId "MDE.AV16" -SettingName "Signature Update Interval" -Category "Signatur & Cloud" -Severity "High" -TestType "Automated" -Description "Verify that signature update interval is configured between 1-4 hours considering bandwidth." -SecurityImpact "Infrequent signature updates reduce detection of latest threats" -ActionSteps @("Set **Signature Update Interval** to 1-4 hours") -ComplianceParameters @{
        ComplianceCheck = "Range"
        ExpectedValue = 2
        RangeMin = 1
        RangeMax = 4
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_signatureupdateinterval"
    }

    $configurations["MDE.AV17"] = New-MdeTestConfig -TestId "MDE.AV17" -SettingName "PUA Protection" -Category "Protection" -Severity "High" -TestType "Automated" -Description "Verify that PUA (Potentially Unwanted Applications) protection is enabled to block Shadow IT." -SecurityImpact "Disabled PUA protection allows Shadow IT and potentially unwanted applications" -ActionSteps @("Set **PUA Protection** to On - Block mode") -ComplianceParameters @{
        ComplianceCheck = "Enum"
        ExpectedValue = "_1"
        ValidValues = @("_1", "_2")
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_puaprotection"
    }

    $configurations["MDE.AV18"] = New-MdeTestConfig -TestId "MDE.AV18" -SettingName "Network Protection" -Category "Advanced Protection" -Severity "High" -TestType "Automated" -Description "Verify that Network Protection is enabled in block mode." -SecurityImpact "Disabled network protection allows web-based threats and malicious IP connections" -ActionSteps @("Set **Network Protection** to Enabled or Audit mode") -ComplianceParameters @{
        ComplianceCheck = "Enum"
        ExpectedValue = "_1"
        ValidValues = @("_1", "_2")
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_enablenetworkprotection"
    }

    $configurations["MDE.AV19"] = New-MdeTestConfig -TestId "MDE.AV19" -SettingName "Disable Local Admin Merge" -Category "Protection" -Severity "Critical" -TestType "Automated" -Description "Verify that local admin merge is disabled to block local exclusions." -SecurityImpact "Local admin policy override allows privilege escalation to bypass security controls" -ActionSteps @("Enable **Disable Local Admin Merge** to prevent local overrides") -ComplianceParameters @{
        ComplianceCheck = "Boolean"
        ExpectedValue = "_1"
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_defender_configuration_disablelocaladminmerge"
    }

    $configurations["MDE.AV20"] = New-MdeTestConfig -TestId "MDE.AV20" -SettingName "Tamper Protection" -Category "Protection" -Severity "Critical" -TestType "Manual" -Description "Verify that Tamper Protection is enabled tenant-wide." -SecurityImpact "Disabled tamper protection allows local administrators to disable security features" -ActionSteps @("Enable **Tamper Protection** tenant-wide in Microsoft 365 Defender portal") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Enabled"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → Tamper Protection"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.AV21"] = New-MdeTestConfig -TestId "MDE.AV21" -SettingName "Real-Time Scan Direction" -Category "Protection" -Severity "Medium" -TestType "Automated" -Description "Verify that real-time scan direction is set to both incoming and outgoing." -SecurityImpact "Limited scan direction may miss malware in certain file operations" -ActionSteps @("Set **Real-time Scan Direction** to Both (incoming and outgoing)") -ComplianceParameters @{
        ComplianceCheck = "Enum"
        ExpectedValue = "_0"
        ValidValues = @("_0", "_1")
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_realtimescandirection"
    }

    $configurations["MDE.AV22"] = New-MdeTestConfig -TestId "MDE.AV22" -SettingName "Retain Cleaned Malware" -Category "Cleanup & Quarantine" -Severity "Medium" -TestType "Automated" -Description "Verify that cleaned malware is retained for 90 days for audit purposes." -SecurityImpact "Short retention may impact forensic analysis and threat investigation" -ActionSteps @("Set **Retain Cleaned Malware** to at least 30 days (recommended: 90 days) for forensic evidence") -ComplianceParameters @{
        ComplianceCheck = "MinimumValue"
        ExpectedValue = 30
        MinimumValue = 30
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_daystoretaincleanedmalware"
    }

    $configurations["MDE.AV23"] = New-MdeTestConfig -TestId "MDE.AV23" -SettingName "Disable Catch-up Full Scan" -Category "Cleanup & Quarantine" -Severity "Low" -TestType "Automated" -Description "Verify that catch-up full scan is disabled to avoid additional load." -SecurityImpact "Enabled catchup scans may cause performance issues on mobile devices" -ActionSteps @("Enable **Disable Catchup Full Scan** to avoid additional system load") -ComplianceParameters @{
        ComplianceCheck = "Boolean"
        ExpectedValue = "_1"
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_disablecatchupfullscan"
    }

    $configurations["MDE.AV24"] = New-MdeTestConfig -TestId "MDE.AV24" -SettingName "Disable Catch-up Quick Scan" -Category "Cleanup & Quarantine" -Severity "Low" -TestType "Automated" -Description "Verify that catch-up quick scan is disabled." -SecurityImpact "Enabled catchup scans may cause performance issues on mobile devices" -ActionSteps @("Enable **Disable Catchup Quick Scan** to avoid additional system load") -ComplianceParameters @{
        ComplianceCheck = "Boolean"
        ExpectedValue = "_1"
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_disablecatchupquickscan"
    }

    $configurations["MDE.AV25"] = New-MdeTestConfig -TestId "MDE.AV25" -SettingName "Remediation Action" -Category "Cleanup & Quarantine" -Severity "High" -TestType "Manual" -Description "Verify that remediation action for all threat levels is set to Quarantine." -SecurityImpact "Inappropriate remediation actions may allow threats to persist or cause data loss" -ActionSteps @("Set **Default Action** to Quarantine for consistent threat handling") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Quarantine"
    } -TestSpecificData @{
        NavigationPath = "Endpoint Security → Antivirus → Threat Severity Default Action"
        PortalUrl = "https://endpoint.microsoft.com"
        SettingId = "device_vendor_msft_policy_config_defender_threatseveritydefaultaction"
    }

    $configurations["MDE.AV26"] = New-MdeTestConfig -TestId "MDE.AV26" -SettingName "Submit Samples Consent" -Category "Cleanup & Quarantine" -Severity "Medium" -TestType "Automated" -Description "Verify that sample submission consent is configured to send safe samples automatically." -SecurityImpact "Restricted sample submission reduces threat intelligence and protection quality" -ActionSteps @("Set **Submit Samples Consent** to send safe samples automatically (check GDPR compliance)") -ComplianceParameters @{
        ComplianceCheck = "Enum"
        ExpectedValue = "_1"
        ValidValues = @("_1", "_2")
    } -TestSpecificData @{
        SettingId = "device_vendor_msft_policy_config_defender_submitsamplesconsent"
    }

    # Global Configuration Tests (MDE.GC01-MDE.GC16)
    $configurations["MDE.GC01"] = New-MdeTestConfig -TestId "MDE.GC01" -SettingName "Preview Features" -Category "Global Config" -Severity "Low" -TestType "GlobalConfig" -Description "Verify that Preview Features are enabled organization-wide in Microsoft Defender XDR." -SecurityImpact "Disabled preview features may result in missing new security capabilities and protections" -ActionSteps @("Enable **Preview Features** organization-wide") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "On"
    } -TestSpecificData @{
        NavigationPath = "Settings → Microsoft Defender XDR → Preview Features"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC02"] = New-MdeTestConfig -TestId "MDE.GC02" -SettingName "Tamper Protection" -Category "Global Config" -Severity "High" -TestType "GlobalConfig" -Description "Verify that Tamper Protection is enabled tenant-wide in Advanced Features." -SecurityImpact "Disabled tamper protection allows local administrators to disable security features" -ActionSteps @("Enable **Tamper Protection** tenant-wide") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Enabled"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → Tamper Protection"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC03"] = New-MdeTestConfig -TestId "MDE.GC03" -SettingName "EDR in Block Mode" -Category "Global Config" -Severity "High" -TestType "GlobalConfig" -Description "Verify that EDR in Block Mode is enabled for Microsoft Defender Antivirus devices." -SecurityImpact "Disabled EDR block mode reduces ability to block threats in real-time" -ActionSteps @("Enable **EDR in Block Mode** for Defender AV devices") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Enabled"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → EDR in Block Mode"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC04"] = New-MdeTestConfig -TestId "MDE.GC04" -SettingName "Automatically Resolve Alerts" -Category "Global Config" -Severity "Medium" -TestType "GlobalConfig" -Description "Verify that Automatically Resolve Alerts is properly configured." -SecurityImpact "Manual alert resolution increases workload and may delay response" -ActionSteps @("Configure **Auto-resolution** for appropriate alert types") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Configured"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → Auto-resolution"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC05"] = New-MdeTestConfig -TestId "MDE.GC05" -SettingName "Allow or Block File" -Category "Global Config" -Severity "Medium" -TestType "GlobalConfig" -Description "Verify that Allow or Block File capability is enabled for IOC handling." -SecurityImpact "Disabled file blocking reduces ability to quickly respond to threats" -ActionSteps @("Enable **Allow or Block File** capability") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Enabled"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → Allow or Block File"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC06"] = New-MdeTestConfig -TestId "MDE.GC06" -SettingName "Hide Duplicate Device Records" -Category "Global Config" -Severity "Low" -TestType "GlobalConfig" -Description "Verify that Hide Duplicate Device Records is enabled to reduce clutter." -SecurityImpact "Duplicate records create confusion in device management" -ActionSteps @("Enable **Hide Duplicate Device Records**") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Enabled"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → Device Management"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC07"] = New-MdeTestConfig -TestId "MDE.GC07" -SettingName "Custom Network Indicators" -Category "Global Config" -Severity "High" -TestType "GlobalConfig" -Description "Verify that Custom Network Indicators are enabled for IOC management." -SecurityImpact "Disabled network indicators reduce ability to block malicious IPs and URLs" -ActionSteps @("Enable **Custom Network Indicators**") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Enabled"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → Indicators"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC08"] = New-MdeTestConfig -TestId "MDE.GC08" -SettingName "Web Content Filtering" -Category "Global Config" -Severity "High" -TestType "GlobalConfig" -Description "Verify that Web Content Filtering is enabled (requires Defender for Endpoint P2 license)." -SecurityImpact "Disabled web filtering allows access to malicious websites" -ActionSteps @("Enable **Web Content Filtering** (requires P2 license)") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Enabled"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → Web Content Filtering"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC09"] = New-MdeTestConfig -TestId "MDE.GC09" -SettingName "Device Discovery" -Category "Global Config" -Severity "Medium" -TestType "GlobalConfig" -Description "Verify that Device Discovery is enabled for Shadow IT visibility." -SecurityImpact "Disabled device discovery reduces visibility into unmanaged devices" -ActionSteps @("Enable **Device Discovery** for Shadow IT visibility") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Enabled"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → Device Discovery"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC10"] = New-MdeTestConfig -TestId "MDE.GC10" -SettingName "Download Quarantined Files" -Category "Global Config" -Severity "Medium" -TestType "GlobalConfig" -Description "Verify that Download Quarantined Files capability is enabled for forensic analysis." -SecurityImpact "Disabled download capability reduces forensic investigation capabilities" -ActionSteps @("Enable **Download Quarantined Files** for forensics") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Enabled"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → General"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC11"] = New-MdeTestConfig -TestId "MDE.GC11" -SettingName "Streamlined Connectivity" -Category "Global Config" -Severity "Medium" -TestType "GlobalConfig" -Description "Verify that Streamlined Connectivity is enabled as default configuration." -SecurityImpact "Disabled streamlined connectivity may affect sensor communication" -ActionSteps @("Enable **Streamlined Connectivity** as default") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Enabled"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → General"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC12"] = New-MdeTestConfig -TestId "MDE.GC12" -SettingName "Apply Streamlined Connectivity to Intune/DFC" -Category "Global Config" -Severity "Medium" -TestType "GlobalConfig" -Description "Verify that Streamlined Connectivity is applied to Intune/DFC for synchronization." -SecurityImpact "Poor Intune integration affects device management sync" -ActionSteps @("Enable **Streamlined Connectivity to Intune/DFC**") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Enabled"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → General"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC13"] = New-MdeTestConfig -TestId "MDE.GC13" -SettingName "Isolation Exclusion Rules" -Category "Global Config" -Severity "High" -TestType "GlobalConfig" -Description "Verify that Isolation Exclusion Rules are disabled unless specifically required." -SecurityImpact "Broad isolation exclusions reduce incident response capabilities" -ActionSteps @("Disable **Isolation Exclusion Rules** unless business-justified") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Disabled"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → General"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC14"] = New-MdeTestConfig -TestId "MDE.GC14" -SettingName "Deception Capabilities" -Category "Global Config" -Severity "Low" -TestType "GlobalConfig" -Description "Verify that Deception capabilities are properly evaluated (optional honeypot deployment)." -SecurityImpact "Unused deception capabilities miss advanced threat detection opportunities" -ActionSteps @("Evaluate **Deception** capabilities for honeypot deployment") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Evaluated"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → General"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC15"] = New-MdeTestConfig -TestId "MDE.GC15" -SettingName "Microsoft Intune Connection" -Category "Global Config" -Severity "Medium" -TestType "GlobalConfig" -Description "Verify that Microsoft Intune Connection is enabled as prerequisite for MDM integration." -SecurityImpact "Disabled Intune connection affects device management integration" -ActionSteps @("Enable **Microsoft Intune Connection** for MDM integration") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Enabled"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → General"
        PortalUrl = "https://security.microsoft.com"
    }

    $configurations["MDE.GC16"] = New-MdeTestConfig -TestId "MDE.GC16" -SettingName "Authenticated Telemetry" -Category "Global Config" -Severity "Low" -TestType "GlobalConfig" -Description "Verify that Authenticated Telemetry settings comply with privacy requirements." -SecurityImpact "Inappropriate telemetry settings may violate privacy regulations" -ActionSteps @("Review **Authenticated Telemetry** for privacy compliance") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Compliant"
    } -TestSpecificData @{
        NavigationPath = "Settings → Endpoints → Advanced Features → General"
        PortalUrl = "https://security.microsoft.com"
    }

    # Policy Design Tests (MDE.PD01-MDE.PD04)
    $configurations["MDE.PD01"] = New-MdeTestConfig -TestId "MDE.PD01" -SettingName "Policy Naming Convention" -Category "Policy Design" -Severity "Low" -TestType "PolicyDesign" -Description "Verify consistent policy naming convention across all MDE policies." -SecurityImpact "Inconsistent naming creates confusion and management overhead in large environments" -ActionSteps @("Implement consistent naming convention (ROLE-v#) across all MDE policies") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Consistent naming (ROLE-v#)"
    } -TestSpecificData @{
        NavigationPath = "Microsoft Endpoint Manager → Endpoint Security → Antivirus"
        PortalUrl = "https://endpoint.microsoft.com"
    }

    $configurations["MDE.PD02"] = New-MdeTestConfig -TestId "MDE.PD02" -SettingName "Exclusions in Dedicated Profiles" -Category "Policy Design" -Severity "Medium" -TestType "PolicyDesign" -Description "Verify that exclusions are configured in dedicated profiles to reduce baseline complexity." -SecurityImpact "Mixed baseline and exclusion policies create complexity and potential conflicts" -ActionSteps @("Separate exclusions into dedicated profiles away from baseline policies") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Separated profiles"
    } -TestSpecificData @{
        NavigationPath = "Microsoft Endpoint Manager → Endpoint Security → Antivirus"
        PortalUrl = "https://endpoint.microsoft.com"
    }

    $configurations["MDE.PD03"] = New-MdeTestConfig -TestId "MDE.PD03" -SettingName "Granular Device Profiles" -Category "Policy Design" -Severity "Medium" -TestType "PolicyDesign" -Description "Verify that device profiles are granular and follow least privilege principle." -SecurityImpact "Broad device assignments reduce security and increase complexity" -ActionSteps @("Implement granular device targeting based on roles and least privilege") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Granular targeting"
    } -TestSpecificData @{
        NavigationPath = "Microsoft Endpoint Manager → Groups → Device Groups"
        PortalUrl = "https://endpoint.microsoft.com"
    }

    $configurations["MDE.PD04"] = New-MdeTestConfig -TestId "MDE.PD04" -SettingName "Staging Deployment Buckets" -Category "Policy Design" -Severity "Medium" -TestType "PolicyDesign" -Description "Verify that staging deployment buckets are implemented (e.g., DG-CL-GEN-PILOT → PROD)." -SecurityImpact "Direct production deployment increases risk of widespread issues" -ActionSteps @("Implement staging buckets (Pilot → Production) for gradual rollout") -ComplianceParameters @{
        ComplianceCheck = "Manual"
        ExpectedValue = "Pilot → Prod buckets"
    } -TestSpecificData @{
        NavigationPath = "Microsoft Endpoint Manager → Groups → Device Groups"
        PortalUrl = "https://endpoint.microsoft.com"
    }

    # Apply MDE config overrides for ComplianceLogic
    foreach ($configKey in $configurations.Keys) {
        $testSpecificConfig = $mdeConfig.TestSpecific.$configKey
        if ($testSpecificConfig -and $testSpecificConfig.ComplianceLogic) {
            $configurations[$configKey].ComplianceLogic = $testSpecificConfig.ComplianceLogic
        } else {
            $configurations[$configKey].ComplianceLogic = $mdeConfig.ComplianceLogic
        }
    }

    if ($TestId) {
        return $configurations[$TestId]
    } else {
        return $configurations
    }
}

#endregion