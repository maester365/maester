# MS.AAD: Checks if Conditional Access Policy using Phishing-Resistant Authentication Strengths is enabled

## Overview

**Function Name:** `Test-MtCisaPhishResistant`
**Category:** CISA/Entra
**Test Tag:** `MS.AAD`

## Description

Phishing-resistant MFA SHALL be enforced for all users

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Prerequisites Check}
    B -->|Connection Required| C{Check Connections}
    C -->|Microsoft Graph| D{License Check}
    D -->|Entra ID| E[Data Collection]
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

**Required Licenses:**
- Entra ID

### Phase 2: Data Collection

**Cmdlets/Functions Used:**
- `Get-MtConditionalAccessPolicy`

### Phase 3: Compliance Validation

The function validates the collected data against compliance requirements.

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant |
| `$false` | Non-Compliant |
| `$null` | Skipped (missing prerequisites, license, or error) |

## Original Documentation

Phishing-resistant MFA SHALL be enforced for all users.

Rationale: Weaker forms of MFA do not protect against sophisticated phishing attacks. By enforcing methods resistant to phishing, those risks are minimized.

#### Remediation action:

Create a conditional access policy enforcing phishing-resistant MFA for all users. Configure the following policy settings in the new conditional access policy, per the values below:

* Users > Include > **All users**
* Target resources > Cloud apps > **All cloud apps**
* Access controls > Grant > Grant Access > Require authentication strength > **Phishing-resistant MFA**

#### Related links

* [CISA Strong Authentication & Secure Registration - MS.AAD.3.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad31v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L181)

<!--- Results --->
%TestResult%

## Standalone Function

See the standalone compliance check function: [`Test-MtCisaPhishResistantCompliance.ps1`](../../standalone-functions/CISA/Entra/Test-MtCisaPhishResistantCompliance.ps1)
