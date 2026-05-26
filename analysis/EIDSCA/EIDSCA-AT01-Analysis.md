# EIDSCA.AT01: Authentication Method - Temporary Access Pass - State

## Overview

**Check ID:** `AT01`
**Tag:** `EIDSCA.AT01`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AT01: Authentication Method - Temporary Access Pass - State. See https://maester.dev/docs/tests/EIDSCA.AT01

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authenticationMeth...| D[Extract Property]
    D -->|state| E{Validate Value}
    E -->|Expected: enabled| F{Return Result}
    F -->|Match| G[Return Pass]
    F -->|No Match| H[Return Fail]
    B -->|Not Connected| I[Skip]
```

## Phase Details

### Phase 1: Prerequisites
- Microsoft Graph connection required

### Phase 2: Data Collection
- **API Endpoint:** `https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')`
- **Property Path:** `state`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `state` | `-Be` | `enabled` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAT01Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAT01Compliance.ps1)