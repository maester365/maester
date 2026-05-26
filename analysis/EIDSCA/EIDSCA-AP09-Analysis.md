# EIDSCA.AP09: Default Authorization Settings - Allow user consent on risk-based apps

## Overview

**Check ID:** `AP09`
**Tag:** `EIDSCA.AP09`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AP09: Default Authorization Settings - Allow user consent on risk-based apps. See https://maester.dev/docs/tests/EIDSCA.AP09

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authorizationPolic...| D[Extract Property]
    D -->|allowUserConsentForRiskyApps| E{Validate Value}
    E -->|Expected: false| F{Return Result}
    F -->|Match| G[Return Pass]
    F -->|No Match| H[Return Fail]
    B -->|Not Connected| I[Skip]
```

## Phase Details

### Phase 1: Prerequisites
- Microsoft Graph connection required

### Phase 2: Data Collection
- **API Endpoint:** `https://graph.microsoft.com/beta/policies/authorizationPolicy`
- **Property Path:** `allowUserConsentForRiskyApps`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `allowUserConsentForRiskyApps` | `-Be` | `false` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAP09Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAP09Compliance.ps1)