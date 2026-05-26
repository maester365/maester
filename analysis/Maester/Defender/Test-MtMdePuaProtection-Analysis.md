# Test-MtMdePuaProtection: Checks if PUA (Potentially Unwanted Applications) protection is enabled

## Overview

**Function Name:** `Test-MtMdePuaProtection`
**Category:** Maester/Defender

## Description

Tests that all assigned Microsoft Defender Antivirus policies have PUA
        protection enabled in block or audit mode. Disabled PUA protection allows
        Shadow IT and potentially unwanted applications on managed devices.

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Prerequisites Check}
    B -->|Connection Required| C{Check Connections}
    C -->|Microsoft Graph| D{License Check}
    D -->|No specific license| E[Data Collection]
    E --> F[Compliance Validation]
    F --> G{Return Result}
    G -->|Pass| I[Return True]
    G -->|Fail| J[Return False]
    B -->|Not Connected| K[Return Null - Skipped]
```

## Phase Details

### Phase 1: Prerequisites Check

**Required Connections:**
- Microsoft Graph

### Phase 2: Data Collection

**Cmdlets/Functions Used:**
- `Get-MdeDeviceCount`
- `Get-MdePolicyConfiguration`

### Phase 3: Compliance Validation

The function validates the collected data against compliance requirements.

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant |
| `$false` | Non-Compliant |
| `$null` | Skipped (missing prerequisites, license, or error) |

## Original Documentation

Checks that PUA (Potentially Unwanted Applications) protection is enabled in all assigned Microsoft Defender Antivirus policies.

Disabled PUA protection allows Shadow IT and potentially unwanted applications to be installed on managed devices, increasing the attack surface.

#### Remediation action:

1. Open [Microsoft Endpoint Manager](https://endpoint.microsoft.com) > **Endpoint Security** > **Antivirus**
2. Edit the relevant Microsoft Defender Antivirus policy
3. Set **PUA Protection** to On (Block mode)

#### Related links

- [Configure Microsoft Defender Antivirus](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/configure-microsoft-defender-antivirus-features)
- [Microsoft Endpoint Manager](https://endpoint.microsoft.com)

<!--- Results --->
%TestResult%

## Standalone Function

See the standalone compliance check function: [`Test-MtMdePuaProtectionCompliance.ps1`](../../standalone-functions/Maester/Defender/Test-MtMdePuaProtectionCompliance.ps1)
