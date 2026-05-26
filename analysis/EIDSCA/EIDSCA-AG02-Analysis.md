# EIDSCA.AG02: Authentication Method - General Settings - Report suspicious activity - State

## Overview

**Check ID:** `AG02`
**Tag:** `EIDSCA.AG02`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AG02: Authentication Method - General Settings - Report suspicious activity - State. See https://maester.dev/docs/tests/EIDSCA.AG02

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authenticationMeth...| D[Extract Property]
    D -->|reportSuspiciousActivitySettings.state| E{Validate Value}
    E -->|Expected: enabled| F{Return Result}
    F -->|Match| G[Return Pass]
    F -->|No Match| H[Return Fail]
    B -->|Not Connected| I[Skip]
```

## Phase Details

### Phase 1: Prerequisites
- Microsoft Graph connection required

### Phase 2: Data Collection
- **API Endpoint:** `https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy`
- **Property Path:** `reportSuspiciousActivitySettings.state`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `reportSuspiciousActivitySettings.state` | `-Be` | `enabled` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAG02Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAG02Compliance.ps1)