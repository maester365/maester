# EIDSCA.AP01: Default Authorization Settings - Enabled Self service password reset for administrators

## Overview

**Check ID:** `AP01`
**Tag:** `EIDSCA.AP01`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AP01: Default Authorization Settings - Enabled Self service password reset for administrators. See https://maester.dev/docs/tests/EIDSCA.AP01

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authorizationPolic...| D[Extract Property]
    D -->|allowedToUseSSPR| E{Validate Value}
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
- **Property Path:** `allowedToUseSSPR`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `allowedToUseSSPR` | `-Be` | `false` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAP01Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAP01Compliance.ps1)