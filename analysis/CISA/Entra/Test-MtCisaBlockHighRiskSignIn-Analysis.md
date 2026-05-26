# MS.AAD: Checks if Sign-In Risk Based Policies - MS.AAD.2.3 is set to 'blocked'

## Overview

**Function Name:** `Test-MtCisaBlockHighRiskSignIn`
**Category:** CISA/Entra
**Test Tag:** `MS.AAD`

## Description

Sign-ins detected as high risk SHALL be blocked.

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Prerequisites Check}
    B -->|Connection Required| C{Check Connections}
    C -->|Microsoft Graph| D{License Check}
    D -->|Entra ID P2| E[Data Collection]
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
- Entra ID P2

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

Sign-ins detected as high risk SHALL be blocked.

Rationale: Blocking high-risk sign ins may prevent compromised sign-ins from accessing the tenant. This prevents compromised sign-ins from accessing the tenant.

#### Remediation action:

Create a Conditional Access policy blocking sign-ins determined high risk by the Identity Protection service. Configure the following policy settings in the new Conditional Access policy as per the values below:

* Users > Include > **All users**
* Target resources > Cloud apps > **All cloud apps**
* Conditions > Sign-in risk > **High**
* Access controls > Grant > **Block Access**

Note: While CISA recommends blocking, the [Microsoft recommendation](https://learn.microsoft.com/entra/id-protection/howto-identity-protection-configure-risk-policies#microsofts-recommendation) is to require multi-factor authentication for high-risk sign-ins.

#### Related links

* [CISA Risk Based Policies - MS.AAD.2.3](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad23v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L138)

<!--- Results --->
%TestResult%

## Standalone Function

See the standalone compliance check function: [`Test-MtCisaBlockHighRiskSignInCompliance.ps1`](../../standalone-functions/CISA/Entra/Test-MtCisaBlockHighRiskSignInCompliance.ps1)
