<#
.SYNOPSIS
    Helper functions for Microsoft Defender for Endpoint tests

.DESCRIPTION
    Contains functions for device management, policy retrieval, and the unified test engine
    used by all MDE tests in the Maester framework.

.NOTES
    All MDE helper functions are consolidated in this file for easier maintenance.
#>

#Requires -Version 5.1

#region Core Configuration Functions

<#
.SYNOPSIS
    Gets information about your organization's Defender-protected devices and their policies

.DESCRIPTION
    Retrieves device inventory, configuration policies, and compliance information
    from Microsoft Graph API for use in MDE tests.

.PARAMETER DisableCache
    Bypasses the Graph API response cache and fetches fresh data

.EXAMPLE
    Get-MtMdeConfiguration

    Gets current MDE device and policy information
#>
function Get-MtMdeConfiguration {
    [CmdletBinding()]
    param(
        [switch]$DisableCache
    )

    Write-Verbose "Getting managed devices from Microsoft Graph"
    $deviceParams = @{
        RelativeUri = 'deviceManagement/managedDevices'
        ApiVersion = 'v1.0'
        Select = 'id,deviceName,operatingSystem,complianceState,managementAgent,azureADDeviceId,lastSyncDateTime'
        DisableCache = $DisableCache
    }
    $managedDevices = Invoke-MtGraphRequest @deviceParams

    if ($managedDevices) {
        foreach ($device in $managedDevices) {
            if ($device.lastSyncDateTime) {
                try {
                    $parsedDate = [DateTime]::Parse($device.lastSyncDateTime)
                    $device.lastSyncDateTime = $parsedDate.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                } catch {
                    Write-Verbose "Could not parse date for device $($device.deviceName): $($device.lastSyncDateTime)"
                }
            }
        }
    }

    Write-Verbose "Getting device configuration policies"
    $configParams = @{
        RelativeUri = 'deviceManagement/configurationPolicies'
        ApiVersion = 'beta'
        DisableCache = $DisableCache
    }
    $configPolicies = Invoke-MtGraphRequest @configParams

    Write-Verbose "Getting device compliance policies"
    $complianceParams = @{
        RelativeUri = 'deviceManagement/deviceCompliancePolicies'
        ApiVersion = 'v1.0'
        DisableCache = $DisableCache
    }
    $compliancePolicies = Invoke-MtGraphRequest @complianceParams

    Write-Verbose "Getting security baselines"
    $baselinesParams = @{
        RelativeUri = 'deviceManagement/templates'
        ApiVersion = 'beta'
        Filter = "isof('microsoft.graph.securityBaselineTemplate')"
        DisableCache = $DisableCache
    }
    $securityBaselines = Invoke-MtGraphRequest @baselinesParams

    $configuration = @{
        ManagedDevices = $managedDevices
        ConfigurationPolicies = $configPolicies
        CompliancePolicies = $compliancePolicies
        SecurityBaselines = $securityBaselines
        Timestamp = Get-Date
    }

    return $configuration
}

<#
.SYNOPSIS
    Counts how many devices are protected by Microsoft Defender for Endpoint

.DESCRIPTION
    Returns the number of Windows devices that can receive MDE antivirus policies.
    Only includes devices managed by Defender ('msSense') or Intune ('mdm').

.PARAMETER IncludeDetails
    Returns detailed device information instead of just the count

.EXAMPLE
    Get-MtMdeDeviceCount

    Returns the number of MDE-protected devices
#>
function Get-MtMdeDeviceCount {
    [CmdletBinding()]
    [OutputType([int], ParameterSetName = 'Count')]
    [OutputType([hashtable], ParameterSetName = 'Details')]
    param(
        [Parameter(ParameterSetName = 'Details')]
        [switch]$IncludeDetails
    )

    try {
        $mdeConfig = Get-MtMdeConfiguration -ErrorAction SilentlyContinue

        $mdeDevices = @()
        $mdeDeviceCount = 0

        if ($mdeConfig -and $mdeConfig.ManagedDevices) {
            # Only include devices managed by Defender ('msSense') or Intune ('mdm') since these can receive antivirus policies
            $mdeDevices = $mdeConfig.ManagedDevices | Where-Object {
                $_.managementAgent -in @('msSense', 'mdm') -and
                $_.operatingSystem -eq 'Windows'
            }
            $mdeDeviceCount = $mdeDevices.Count
        }

        Write-Verbose "Found $mdeDeviceCount Windows devices eligible for MDE antivirus policy testing (msSense: $(@($mdeDevices | Where-Object {$_.managementAgent -eq 'msSense'}).Count), mdm: $(@($mdeDevices | Where-Object {$_.managementAgent -eq 'mdm'}).Count))"

        if ($IncludeDetails) {
            return @{
                Count = $mdeDeviceCount
                Devices = $mdeDevices
                TotalManagedDevices = if ($mdeConfig.ManagedDevices) { $mdeConfig.ManagedDevices.Count } else { 0 }
            }
        } else {
            return $mdeDeviceCount
        }

    } catch [Microsoft.Graph.PowerShell.Runtime.GraphException] {
        Write-Verbose "Microsoft Graph API error getting MDE device count: $($_.Exception.Message)"

        if ($IncludeDetails) {
            return @{
                Count = 0
                Devices = @()
                TotalManagedDevices = 0
                Error = "Graph API error: $($_.Exception.Message)"
            }
        } else {
            return 0
        }
    } catch [System.UnauthorizedAccessException] {
        Write-Verbose "Insufficient permissions to get MDE device count: $($_.Exception.Message)"

        if ($IncludeDetails) {
            return @{
                Count = 0
                Devices = @()
                TotalManagedDevices = 0
                Error = "Access denied: $($_.Exception.Message)"
            }
        } else {
            return 0
        }
    } catch {
        Write-Verbose "Unexpected error getting MDE device count: $($_.Exception.Message)"

        if ($IncludeDetails) {
            return @{
                Count = 0
                Devices = @()
                TotalManagedDevices = 0
                Error = "Unexpected error: $($_.Exception.Message)"
            }
        } else {
            return 0
        }
    }
}

#endregion

#region Policy Assignment Functions

<#
.SYNOPSIS
    Checks if a policy is assigned to any groups or devices

.DESCRIPTION
    Returns true if the policy has active assignments (not just exclusions).
    This helps ensure we only test policies that are actually deployed.

.PARAMETER PolicyId
    The ID of the policy to check

.PARAMETER PolicyType
    Type of policy: "ConfigurationPolicy" or "DeviceConfiguration"

.EXAMPLE
    Test-MtMdePolicyHasAssignments -PolicyId "abc-123" -PolicyType "ConfigurationPolicy"

    Returns $true if policy is assigned to groups or devices
#>
function Test-MtMdePolicyHasAssignments {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyId,

        [Parameter(Mandatory = $true)]
        [ValidateSet("ConfigurationPolicy")]
        [string]$PolicyType
    )

    try {
        $endpoint = "deviceManagement/configurationPolicies/$PolicyId/assignments"

        $assignmentParams = @{
            RelativeUri = $endpoint
            ApiVersion = 'beta'
            ErrorAction = 'Stop'
        }
        $assignments = Invoke-MtGraphRequest @assignmentParams

        if (-not $assignments -or $assignments.Count -eq 0) {
            Write-Verbose "Policy $PolicyId has no assignments"
            return $false
        }

        # Look for inclusion assignments (not just exclusions)
        $validAssignments = @()
        foreach ($assignment in $assignments) {
            if ($assignment.target.'@odata.type' -in @(
                '#microsoft.graph.groupAssignmentTarget',
                '#microsoft.graph.allDevicesAssignmentTarget',
                '#microsoft.graph.allLicensedUsersAssignmentTarget'
            )) {
                $validAssignments += $assignment
            }
        }

        if ($validAssignments.Count -gt 0) {
            Write-Verbose "Policy $PolicyId has $($validAssignments.Count) valid assignments"
            return $true
        } else {
            Write-Verbose "Policy $PolicyId has only exclusion assignments"
            return $false
        }

    } catch {
        # If we can't check assignments, assume policy is assigned (fail-safe approach)
        Write-Verbose "Error getting assignments for policy $PolicyId - $($_.Exception.Message). Assuming policy is assigned."
        return $true
    }
}

#endregion

#region Policy Retrieval Functions

<#
.SYNOPSIS
    Gets Microsoft Defender Antivirus policies that are assigned to devices

.DESCRIPTION
    Retrieves configuration policies from Microsoft Graph, filters for
    Defender Antivirus policies, and checks which ones are actually assigned.

.OUTPUTS
    Hashtable with ConfigurationPolicies array and TotalCount
#>
function Get-MdePolicyConfiguration {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    try {
        $mdeGlobalConfig = Get-MtMdeConfig
        $mdeConfig = Get-MtMdeConfiguration

        if (-not $mdeConfig) {
            Write-Verbose "Unable to retrieve MDE configuration"
            return @{
                ConfigurationPolicies = @()
                TotalCount = 0
                Error = "Failed to retrieve MDE configuration"
            }
        }

        # Find Microsoft Defender Antivirus policies for Windows
        $configPolicies = @()
        if ($mdeConfig.ConfigurationPolicies) {
            $configPolicies = $mdeConfig.ConfigurationPolicies | Where-Object {
                $_.templateReference.templateDisplayName -eq "Microsoft Defender Antivirus" -and
                $_.platforms -eq "windows10"
            }
        }

        # Apply policy filtering based on configuration
        $finalConfigPolicies = @()

        switch ($mdeGlobalConfig.PolicyFiltering) {
            "All" {
                $finalConfigPolicies = $configPolicies
                Write-Verbose "Policy filtering: All - Including all $($configPolicies.Count) policies"
            }
            "IncludeUnassigned" {
                $finalConfigPolicies = $configPolicies
                Write-Verbose "Policy filtering: IncludeUnassigned - Including all $($configPolicies.Count) policies"
            }
            "OnlyAssigned" {
                if ($configPolicies.Count -gt 0) {
                    Write-Verbose "Checking assignments for $($configPolicies.Count) policies"
                    foreach ($policy in $configPolicies) {
                        if (Test-MtMdePolicyHasAssignments -PolicyId $policy.id -PolicyType "ConfigurationPolicy") {
                            $finalConfigPolicies += $policy
                        }
                    }
                    Write-Verbose "Found $($finalConfigPolicies.Count) assigned policies"
                }
            }
            default {
                Write-Verbose "Invalid PolicyFiltering value '$($mdeGlobalConfig.PolicyFiltering)', defaulting to OnlyAssigned"
                if ($configPolicies.Count -gt 0) {
                    foreach ($policy in $configPolicies) {
                        if (Test-MtMdePolicyHasAssignments -PolicyId $policy.id -PolicyType "ConfigurationPolicy") {
                            $finalConfigPolicies += $policy
                        }
                    }
                }
            }
        }

        return @{
            ConfigurationPolicies = $finalConfigPolicies
            TotalCount = $finalConfigPolicies.Count
        }

    } catch [Microsoft.Graph.PowerShell.Runtime.GraphException] {
        Write-Verbose "Microsoft Graph API error retrieving MDE policies: $($_.Exception.Message)"
        return @{
            ConfigurationPolicies = @()
            TotalCount = 0
            Error = "Graph API error: $($_.Exception.Message)"
        }
    } catch [System.UnauthorizedAccessException] {
        Write-Verbose "Insufficient permissions to retrieve MDE policies: $($_.Exception.Message)"
        return @{
            ConfigurationPolicies = @()
            TotalCount = 0
            Error = "Access denied: $($_.Exception.Message)"
        }
    } catch {
        Write-Verbose "Unexpected error retrieving MDE policies: $($_.Exception.Message)"
        return @{
            ConfigurationPolicies = @()
            TotalCount = 0
            Error = "Unexpected error: $($_.Exception.Message)"
        }
    }
}
#endregion

#region Policy Compliance Functions
<#
.SYNOPSIS
    Tests policy compliance for MDE settings

.DESCRIPTION
    Analyzes configuration policies for compliance with the specified setting.
    Returns detailed compliance results categorized by compliant, non-compliant, and not-configured.

.PARAMETER PolicyConfiguration
    Policy configuration object from Get-MdePolicyConfiguration

.PARAMETER SettingConfig
    Setting configuration object containing compliance criteria

.OUTPUTS
    Hashtable containing compliance analysis results
#>
function Test-MdePolicyCompliance {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$PolicyConfiguration,

        [Parameter(Mandatory = $true)]
        [hashtable]$SettingConfig
    )

    $compliantPolicies = @()
    $nonCompliantPolicies = @()
    $notConfiguredPolicies = @()

    # Focus only on Settings Catalog policies

    # Check new configuration policies
    if ($PolicyConfiguration.ConfigurationPolicies.Count -gt 0) {
        foreach ($policy in $PolicyConfiguration.ConfigurationPolicies) {
            try {
                # Get all settings using Maester framework (includes automatic paging)
                $settingsParams = @{
                    RelativeUri = "deviceManagement/configurationPolicies/$($policy.id)/settings"
                    ApiVersion = 'beta'
                    ErrorAction = 'SilentlyContinue'
                }
                $policySettings = Invoke-MtGraphRequest @settingsParams

                $specificSetting = $policySettings | Where-Object {
                    $_.settingInstance.settingDefinitionId -eq $SettingConfig.TestSpecificData.SettingId
                }

                if ($specificSetting) {
                    $settingValue = Get-MdeSettingValue -Setting $specificSetting -SettingConfig $SettingConfig
                    $complianceResult = Test-MdeSettingCompliance -Value $settingValue -SettingConfig $SettingConfig

                    switch ($complianceResult) {
                        "Compliant" { $compliantPolicies += $policy.name }
                        "NonCompliant" { $nonCompliantPolicies += $policy.name }
                        "NotConfigured" { $notConfiguredPolicies += $policy.name }
                    }
                } else {
                    # Policy exists but setting not configured
                    $notConfiguredPolicies += $policy.name
                }
            } catch [Microsoft.Graph.PowerShell.Runtime.GraphException] {
                Write-Verbose "Graph API error analyzing configuration policy $($policy.name): $($_.Exception.Message)"
                $notConfiguredPolicies += $policy.name
            } catch {
                Write-Verbose "Error analyzing configuration policy $($policy.name): $($_.Exception.Message)"
                $notConfiguredPolicies += $policy.name
            }
        }
    }

    return @{
        CompliantPolicies = $compliantPolicies
        NonCompliantPolicies = $nonCompliantPolicies
        NotConfiguredPolicies = $notConfiguredPolicies
        HasCompliant = $compliantPolicies.Count -gt 0
        HasNonCompliant = $nonCompliantPolicies.Count -gt 0
        HasNotConfigured = $notConfiguredPolicies.Count -gt 0
    }
}


<#
.SYNOPSIS
    Tests compliance for a specific setting value

.DESCRIPTION
    Evaluates a setting value against the configuration criteria to determine
    if it meets compliance requirements.

.PARAMETER Value
    The setting value to test

.PARAMETER SettingConfig
    Configuration object containing compliance criteria

.OUTPUTS
    String - "Compliant", "NonCompliant", or "NotConfigured"
#>
function Test-MdeSettingCompliance {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        $Value,
        [Parameter(Mandatory = $true)]
        [hashtable]$SettingConfig
    )

    if ($null -eq $Value -or $Value -eq "") {
        return "NotConfigured"
    }

    switch ($SettingConfig.ComplianceParameters.ComplianceCheck) {
        "Boolean" {
            # Compare string values directly (e.g., "_1" with "_1")
            if ([string]$Value -eq [string]$SettingConfig.ComplianceParameters.ExpectedValue) {
                return "Compliant"
            } else {
                return "NonCompliant"
            }
        }
        "Range" {
            # Convert to numeric for range comparison
            try {
                $numValue = [int]$Value
                $min = $SettingConfig.ComplianceParameters.RangeMin
                $max = $SettingConfig.ComplianceParameters.RangeMax
                if ($numValue -ge $min -and $numValue -le $max) {
                    return "Compliant"
                } else {
                    return "NonCompliant"
                }
            } catch {
                return "NonCompliant"
            }
        }
        "Enum" {
            # Compare string values directly (e.g., "_1" with allowed values)
            if ([string]$Value -in $SettingConfig.ComplianceParameters.ValidValues) {
                return "Compliant"
            } else {
                return "NonCompliant"
            }
        }
        "MinimumLevel" {
            # Compare numeric level values (e.g., Cloud Block Level)
            if ($SettingConfig.ComplianceParameters.ValidLevels -and $SettingConfig.ComplianceParameters.ValidLevels.ContainsKey([string]$Value)) {
                $actualLevel = $SettingConfig.ComplianceParameters.ValidLevels[[string]$Value]
                $minimumLevel = $SettingConfig.ComplianceParameters.MinimumValue
                if ($actualLevel -ge $minimumLevel) {
                    return "Compliant"
                } else {
                    return "NonCompliant"
                }
            } else {
                return "NonCompliant"
            }
        }
        "MinimumValue" {
            # Compare numeric values with minimum threshold (e.g., Retention Days)
            try {
                $numValue = [int]$Value
                $minimumValue = $SettingConfig.ComplianceParameters.MinimumValue
                if ($numValue -ge $minimumValue) {
                    return "Compliant"
                } else {
                    return "NonCompliant"
                }
            } catch {
                return "NonCompliant"
            }
        }
        "NotRequired" {
            # This setting is not required for compliance
            return "Compliant"
        }
        "Manual" {
            # This setting requires manual verification
            return "NotConfigured"
        }
        "Custom" {
            if ($SettingConfig.CustomValidation) {
                $result = & $SettingConfig.CustomValidation $Value
                return if ($result) { "Compliant" } else { "NonCompliant" }
            }
            return "NotConfigured"
        }
        default {
            return "NotConfigured"
        }
    }
}
#endregion

#region Configuration Setting Value parser
<#
.SYNOPSIS
    Extracts setting values from Graph API responses

.DESCRIPTION
    Parses setting objects from Microsoft Graph API configuration policy responses
    and extracts the appropriate value based on the setting type.

.PARAMETER Setting
    The setting object from Graph API

.PARAMETER SettingConfig
    Configuration object containing extraction logic

.OUTPUTS
    Object - The extracted setting value
#>
function Get-MdeSettingValue {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        $Setting,

        [Parameter(Mandatory = $true)]
        [hashtable]$SettingConfig
    )

    switch ($SettingConfig.ComplianceParameters.ComplianceCheck) {
        "Boolean" {
            $choiceValue = $Setting.settingInstance.choiceSettingValue.value
            # Extract the suffix (_0, _1, etc.) which indicates the Graph API enum value
            if ($choiceValue -match "_(\d)$") {
                return "_$($matches[1])"
            }
            return $null
        }
        "Range" {
            return $Setting.settingInstance.simpleSettingValue.value
        }
        "Enum" {
            $choiceValue = $Setting.settingInstance.choiceSettingValue.value
            # Extract the suffix (_0, _1, _2, etc.) which indicates the Graph API enum value
            if ($choiceValue -match "_(\d)$") {
                return "_$($matches[1])"
            }
            return $choiceValue
        }
        "MinimumLevel" {
            $choiceValue = $Setting.settingInstance.choiceSettingValue.value
            # Extract the suffix for level-based values like Cloud Block Level
            if ($choiceValue -match "_(\d+)$") {
                return "_$($matches[1])"
            }
            return $choiceValue
        }
        "MinimumValue" {
            # Simple numeric values like retention days
            return $Setting.settingInstance.simpleSettingValue.value
        }
        "NotRequired" {
            # Not required settings always return a compliant value
            return "NotRequired"
        }
        "Manual" {
            # Manual settings require manual verification
            return "ManualVerificationRequired"
        }
        default {
            $choiceValue = $Setting.settingInstance.choiceSettingValue.value
            # Extract the suffix for any other setting types
            if ($choiceValue -match "_(\d)$") {
                return "_$($matches[1])"
            }
            return $choiceValue
        }
    }
}
#endregion


#region Unified Test Engine Functions

<#
.SYNOPSIS
    Unified, intelligent test engine for all Microsoft Defender for Endpoint tests

.DESCRIPTION
    This function provides a single, unified testing engine for all MDE test types.
    It automatically handles test skipping based on TestType and ComplianceCheck,
    eliminating the need for redundant manual skipping code in Pester tests.

.PARAMETER TestId
    The MDE test identifier (e.g., "MDE.AV01", "MDE.GC01")

.PARAMETER TestName
    The Pester test name for result tracking (optional, auto-generated if not provided)

.EXAMPLE
    Invoke-MtMdeUnifiedTest -TestId "MDE.AV01"

    Runs the archive scanning test using unified configuration

.EXAMPLE
    Invoke-MtMdeUnifiedTest -TestId "MDE.AV20"

    Automatically skips the tamper protection test since it's marked as Manual
#>
function Invoke-MtMdeUnifiedTest {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TestId,

        [Parameter(Mandatory = $false)]
        [string]$TestName
    )

    try {
        # Get unified configuration
        $config = Get-MtMdeUnifiedConfiguration -TestId $TestId

        if (-not $config) {
            Write-Warning "Configuration not found for TestId: $TestId"
            Add-MtTestResultDetail -Description "Configuration not found for TestId: $TestId" -GraphObjectType 'Devices'
            return $null
        }

        # Auto-generate test name if not provided
        if (-not $TestName) {
            $TestName = "$($config.TestId): $($config.SettingName)"
        }

        # Simple check: If it's a manual test, skip it automatically
        if ($config.ComplianceParameters.ComplianceCheck -eq "Manual" -or $config.TestType -in @("Manual", "GlobalConfig", "PolicyDesign")) {

            # Generate appropriate manual verification markdown
            $manualMarkdown = New-MtMdeManualVerificationMarkdown -Config $config

            # Use Maester's standard skip mechanism for manual tests with details
            $skipBecause = switch ($config.TestType) {
                "GlobalConfig" { "This test requires manual verification in Microsoft 365 Defender portal" }
                "PolicyDesign" { "This test requires manual verification in Microsoft Endpoint Manager portal" }
                default { "This test requires manual verification" }
            }

            # Return a special skip indicator that Pester tests can handle
            return @{
                IsSkipped = $true
                SkipReason = $skipBecause
                TestType = "Manual"
                TestDetails = $manualMarkdown
                Severity = $config.Severity
            }
        }

        # For automated tests, check prerequisites
        if (-not (Test-MtConnection Graph)) {
            Add-MtTestResultDetail -SkippedBecause NotConnectedGraph -GraphObjectType 'Devices'
            return $null
        }

        $mdeDeviceCount = Get-MtMdeDeviceCount
        if ($mdeDeviceCount -eq 0) {
            Add-MtTestResultDetail -Description "No MDE devices found - $($config.SettingName) configuration not applicable" -GraphObjectType 'Devices'
            return $true
        }

        # For automated tests, execute the test logic directly
        if ($config.TestType -eq "Automated") {
            # Get policy configuration using dedicated helper
            $policyConfiguration = Get-MdePolicyConfiguration

            if ($policyConfiguration.Error) {
                Add-MtTestResultDetail -Description "Error retrieving MDE policies: $($policyConfiguration.Error)" -GraphObjectType 'Devices'
                return $null
            }

            if ($policyConfiguration.TotalCount -eq 0) {
                Add-MtTestResultDetail -Description "No assigned Microsoft Defender Antivirus policies found. Unassigned policies are not tested." -GraphObjectType 'Devices'
                return $null
            }

            # Test policy compliance using dedicated helper
            $complianceResults = Test-MdePolicyCompliance -PolicyConfiguration $policyConfiguration -SettingConfig $config

            # Determine test result based on compliance logic
            $testResult = switch ($config.ComplianceLogic) {
                "AtLeastOne" { $complianceResults.HasCompliant -and -not $complianceResults.HasNonCompliant }
                "AllPolicies" { $complianceResults.CompliantPolicies.Count -eq $policyConfiguration.TotalCount }
                default { $complianceResults.HasCompliant -and -not $complianceResults.HasNonCompliant }
            }

            # Prepare objects for reporting
            $failedObjects = @()
            if ($complianceResults.NonCompliantPolicies.Count -gt 0) {
                $failedObjects += $policyConfiguration.ConfigurationPolicies | Where-Object { $_.name -in $complianceResults.NonCompliantPolicies }
            }

            # Generate detailed markdown directly (consolidated from template system)
            $resultStatus = if ($testResult) { "✅ PASSED" } else { "❌ FAILED" }

            # Convert technical expected value to user-friendly format
            $friendlyExpectedValue = switch ($config.ComplianceParameters.ExpectedValue) {
                "_0" { "Disabled" }
                "_1" { "Enabled" }
                "_2" { "Audit Mode" }
                default { $config.ComplianceParameters.ExpectedValue }
            }

            $detailedMarkdown = @"
**Microsoft Defender Antivirus Policy Compliance**

Verifies that assigned Windows Antivirus policies are properly configured. Only policies with active group assignments are tested.

### $($config.TestId): $($config.SettingName) - $resultStatus

**Setting**: $($config.SettingName) | **Expected**: $friendlyExpectedValue | **Category**: $($config.Category) | **Severity**: $($config.Severity)

**Devices**: $mdeDeviceCount MDE Windows devices | **Policies**: $($policyConfiguration.TotalCount) assigned Settings Catalog policies

**Results**: ✅ $($complianceResults.CompliantPolicies.Count) Compliant | ❌ $($complianceResults.NonCompliantPolicies.Count) Non-Compliant | ⚠️ $($complianceResults.NotConfiguredPolicies.Count) Not Configured

$( if ($complianceResults.CompliantPolicies.Count -gt 0) {
"**✅ Compliant Policies**:
$($complianceResults.CompliantPolicies | ForEach-Object { "- $_" } | Out-String)"
} else { "" } )

$( if ($complianceResults.NonCompliantPolicies.Count -gt 0) {
"**❌ Non-Compliant Policies**:
$($complianceResults.NonCompliantPolicies | ForEach-Object { "- $_" } | Out-String)
⚠️ **Impact**: $($config.SecurityImpact)"
} else { "" } )

$( if ($complianceResults.NotConfiguredPolicies.Count -gt 0) {
"**⚠️ Not Configured Policies**:
$($complianceResults.NotConfiguredPolicies | ForEach-Object { "- $_" } | Out-String)"
} else { "" } )

$( if (-not $testResult) {
"**🎯 Action Required**:
1. Open [Endpoint Manager](https://endpoint.microsoft.com) → **Endpoint Security** → **Antivirus**
2. Edit policies: **$($complianceResults.NonCompliantPolicies + $complianceResults.NotConfiguredPolicies -join ', ')**
3. Set **$($config.SettingName)** to: **$friendlyExpectedValue**
4. Deploy changes to device groups"
} else {
"**✅ Compliance Status**: All assigned policies are properly configured."
} )

**Resources**: [Endpoint Manager](https://endpoint.microsoft.com) | [MDE Documentation](https://docs.microsoft.com/en-us/microsoft-365/security/defender-endpoint/microsoft-defender-antivirus-windows)
"@

            # Use -Description parameter with our generated markdown
            Add-MtTestResultDetail -Description $detailedMarkdown -Result $testResult -GraphObjects $failedObjects -GraphObjectType 'Devices' -TestName $TestName -Severity $config.Severity

            return $testResult
        }

        # This should not be reached for properly configured tests
        Write-Warning "Unhandled test type: $($config.TestType) for TestId: $TestId"
        return $null

    } catch {
        # Check if this is a skip-related error (from Set-ItResult)
        if ($_.Exception.Message -match "is skipped") {
            # Don't treat skip operations as errors
            return $null
        }

        # Only treat actual errors as errors
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}

#endregion

#region Manual Verification Markdown Generation
<#
.SYNOPSIS
    Generates manual verification markdown for all test types

.DESCRIPTION
    Creates standardized manual verification instructions based on test configuration.
    This replaces the separate detail formatter functions with a single, unified approach.

.PARAMETER Config
    The unified test configuration object

.OUTPUTS
    String containing formatted markdown for manual verification
#>
function New-MtMdeManualVerificationMarkdown {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    # Determine portal information based on test type
    $portalInfo = switch ($Config.TestType) {
        "PolicyDesign" {
            @{
                Portal = "Microsoft Endpoint Manager Admin Center"
                Url = "https://endpoint.microsoft.com"
                NavPath = "Endpoint Security → Antivirus or Device Configuration"
            }
        }
        "GlobalConfig" {
            @{
                Portal = "Microsoft 365 Defender Portal"
                Url = $Config.TestSpecificData.PortalUrl
                NavPath = $Config.TestSpecificData.NavigationPath
            }
        }
        "Manual" {
            @{
                Portal = if ($Config.TestSpecificData.PortalUrl -like "*endpoint*") { "Microsoft Endpoint Manager" } else { "Microsoft 365 Defender Portal" }
                Url = $Config.TestSpecificData.PortalUrl
                NavPath = $Config.TestSpecificData.NavigationPath
            }
        }
        default {
            @{
                Portal = "Microsoft 365 Defender Portal"
                Url = "https://security.microsoft.com"
                NavPath = "Manual review required"
            }
        }
    }

    # Generate test-specific checklist content based on TestId
    $checklistContent = "- Verify that **$($Config.SettingName)** is configured correctly`n- Ensure configuration aligns with security best practices`n- Document any deviations or exceptions"

    return @"
## $($Config.TestId): $($Config.SettingName) - ⏭️ MANUAL REVIEW REQUIRED

**Test ID**: $($Config.TestId)
**Category**: $($Config.Category)
**Expected**: $($Config.ComplianceParameters.ExpectedValue)
**Severity**: $($Config.Severity)

### 📋 Manual Review Checklist:

**What to Review:**
$checklistContent

### 🎯 Action Required:
1. Open **$($portalInfo.Portal)** $($portalInfo.Url)
2. Navigate to **$($portalInfo.NavPath)**
3. Review current configuration against the checklist above
4. Document findings and compliance status
5. $($Config.ActionSteps -join '; ')

$(if ($Config.TestSpecificData.AuditNote) {
"### 🔍 Audit Note:
$($Config.TestSpecificData.AuditNote)"
})

### ⚠️ Security Impact:
$($Config.SecurityImpact)

### 📊 Compliance Status:
This test requires manual review and cannot be automated. Please perform the review steps above and document your findings in your compliance tracking system.
"@
}

#endregion