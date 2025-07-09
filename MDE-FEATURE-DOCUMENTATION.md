# Microsoft Defender for Endpoint (MDE) Extension for Maester

## Feature Summary

This feature branch extends the Maester security testing framework with comprehensive Microsoft Defender for Endpoint (MDE) policy validation capabilities. The extension includes 46 automated tests covering antivirus configurations, global settings, and policy design quality - all based on real-world MDE deployment experience.

### Key Components
- **26 Antivirus Policy Tests** (MDE.AV01-26): Validate core security settings
- **16 Global Configuration Tests** (MDE.GC01-16): Check tenant-wide advanced features
- **4 Policy Design Tests** (MDE.PD01-04): Ensure consistent naming and structure
- **ASR Rules Category** (WIP): Attack Surface Reduction rules validation (planned)
- **Unified Configuration System**: Single JSON file controls all test behavior
- **Automatic Test Skipping**: Smart logic handles missing dependencies gracefully

## Configuration System

The extension uses a centralized configuration file at `/tests/Maester/Defender/defender-config.json` that controls all MDE test behavior.

### Configuration Structure

```json
{
  "ComplianceLogic": "AllPolicies",
  "PolicyFiltering": "OnlyAssigned",
  "DeviceFiltering": {
    "OperatingSystems": ["Windows"],
    "ManagementAgents": ["msSense", "mdm"],
    "ComplianceStates": ["Compliant", "NonCompliant", "Unknown"]
  },
  "TestSpecific": {
    "MDE.AV01": {
      "ComplianceLogic": "AtLeastOne"
    }
  }
}
```

### Configuration Options

#### ComplianceLogic
- **`AllPolicies`** (default): All applicable policies must be compliant
- **`AtLeastOne`**: At least one policy must be compliant (useful for optional features)

#### PolicyFiltering
- **`OnlyAssigned`** (default): Only test policies with device assignments
- **`All`**: Test all policies regardless of assignments
- **`None`**: Skip policy filtering entirely

#### DeviceFiltering
Controls which devices are considered when evaluating policies:

- **`OperatingSystems`**: `["Windows", "macOS", "iOS", "Android"]`
- **`ManagementAgents`**: `["msSense", "mdm", "configurationManager", "sccm"]`
- **`ComplianceStates`**: `["Compliant", "NonCompliant", "Unknown", "NotApplicable"]`

#### TestSpecific Overrides
Individual tests can override global settings:
```json
"TestSpecific": {
  "MDE.AV01": {
    "ComplianceLogic": "AtLeastOne",
    "PolicyFiltering": "All"
  }
}
```

## Architecture Complexity - Why Not Individual Files?

Initially, we considered creating separate test files for each antivirus setting (26 individual files). However, this approach became impractical due to Microsoft Graph API limitations:

### API Response Challenges
- **Inconsistent Naming**: Settings don't follow predictable patterns (`_1`, `_2`, etc.)
- **Nested Structures**: Configuration policies use complex JSON with varying paths
- **Bulk Responses**: APIs return all settings together, not individually
- **Performance**: 26 separate API calls would be inefficient and hit rate limits

### Unified Engine Benefits
Instead, we implemented a unified test engine that:
- Makes a single API call to retrieve all antivirus policies
- Processes 26 different settings from the same response
- Applies consistent compliance logic across all tests
- Reduces code duplication by 90%
- Handles skip conditions uniformly

```powershell
# Single function handles all 26 antivirus tests
Invoke-MtMdeUnifiedTest -TestId "MDE.AV01" -ConfigKey "allowArchiveScanning"
Invoke-MtMdeUnifiedTest -TestId "MDE.AV02" -ConfigKey "allowBehaviorMonitoring"
# ... etc
```

## Test Categories and Baseline

All tests are based on practical experience from real-world MDE deployments and industry best practices. The test categories reflect common security challenges:

### 1. Antivirus Baseline (MDE.AV01-26)
Core protection settings that form the foundation of endpoint security:

| Test ID | Setting | Expected Value | Severity | Rationale |
|---------|---------|---------------|----------|-----------|
| MDE.AV01 | Archive Scanning | Enabled | 🟡 Medium | Malware often hides in compressed files |
| MDE.AV02 | Behavior Monitoring | Enabled | 🟠 High | Required for EDR capabilities |
| MDE.AV03 | Cloud Protection | Enabled | 🟠 High | Zero-day protection via cloud intelligence |
| MDE.AV06 | Realtime Monitoring | Enabled | 🔴 Critical | Core protection mechanism |
| MDE.AV17 | PUA Protection | Block Mode | 🟠 High | Prevents unwanted software installations |
| MDE.AV19 | Disable Local Admin Merge | Enabled | 🔴 Critical | Prevents local policy bypasses |
| MDE.AV20 | Tamper Protection | Enabled | 🔴 Critical | Protects against malicious disabling |

*Complete list includes 26 settings covering scan engines, cloud protection, scheduling, and remediation*

### 2. Global Configuration (MDE.GC01-16)
Tenant-wide advanced features that enhance security posture:

| Test ID | Feature | Expected | Severity | Note |
|---------|---------|----------|----------|------|
| MDE.GC02 | Tamper Protection (Global) | On | 🟠 High | Tenant-wide enforcement |
| MDE.GC03 | EDR in Block Mode | On | 🟠 High | Only for Defender AV devices |
| MDE.GC07 | Custom Network Indicators | On | 🟠 High | IOC-based blocking |
| MDE.GC08 | Web Content Filtering | On | 🟠 High | Requires P2 licensing |

**Important**: Global configuration settings cannot currently be validated via Microsoft Graph API. Microsoft has not exposed these tenant-level settings through programmatic access. These tests are included but will be automatically skipped, serving as documentation of recommended settings that must be verified manually through the Microsoft 365 Defender portal.

### 3. Policy Design Quality (MDE.PD01-04)
Governance and organizational best practices:

| Test ID | Check | Purpose | Severity |
|---------|-------|---------|----------|
| MDE.PD01 | Consistent Naming Convention | Policy organization | 🟢 Low |
| MDE.PD02 | Dedicated Exclusion Profiles | Separation of concerns | 🟡 Medium |
| MDE.PD03 | Granular Device Targeting | Least privilege principle | 🟡 Medium |
| MDE.PD04 | Staging Groups (Pilot→Prod) | Change management | 🟡 Medium |

## Test Execution and Results

### Severity Levels
- **🔴 Critical**: Core security functions that must never be disabled
- **🟠 High**: Important security features with significant impact
- **🟡 Medium**: Standard features that improve security posture
- **🟢 Low**: Performance optimizations and nice-to-have features

### Skip Logic
Tests are automatically skipped when:
- No Graph connection available
- No MDE-enrolled devices found
- No relevant policies configured
- API permissions insufficient

### Sample Usage
```powershell
# Connect to required services
Connect-Maester -Service Graph

# Run all MDE tests with Maester
Invoke-Maester -Path "./tests/Maester/Defender/"

# Generate HTML report using Maester
Invoke-Maester -Path "./tests/Maester/Defender/" -OutputHtml "mde-report.html"
```

## Test Tags and Organization

All MDE tests use consistent Pester tags for easy filtering and organization:

### Tag Structure
- **`MDE`**: Applied to all MDE-related tests (universal tag)
- **`MDE-Antivirus`**: Antivirus policy content tests (MDE.AV01-26)
- **`MDE-GlobalConfig`**: Global configuration tests (MDE.GC01-16)
- **`MDE-PolicyDesign`**: Policy design quality tests (MDE.PD01-04)
- **`MDE-ASR`**: Attack Surface Reduction rules (planned/WIP)

### Usage Examples
```powershell
# Run all MDE tests
Invoke-Maester -Tag "MDE"

# Run only antivirus policy tests
Invoke-Maester -Tag "MDE-Antivirus"

# Run specific test by ID
Invoke-Maester -Tag "MDE.AV01"

# Exclude global config tests (since they skip anyway)
Invoke-Maester -Tag "MDE" -ExcludeTag "MDE-GlobalConfig"
```

## Roadmap and Future Development

### Work in Progress
- **ASR Rules Category**: Implementation of Attack Surface Reduction rules validation is planned and will follow the same unified engine pattern established for antivirus tests.

## Integration with Maester Framework

This extension follows Maester's architectural principles:
- Uses existing connection management (`Connect-Maester`)
- Leverages framework helpers (`Add-MtTestResultDetail`, `Invoke-MtGraphRequest`)
- Maintains consistent test patterns and result formatting
- Preserves compatibility with framework updates