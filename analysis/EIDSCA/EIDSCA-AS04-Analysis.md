# EIDSCA.AS04: Authentication Method - SMS - Use for sign-in

## Overview

**Check ID:** `AS04`
**Tag:** `EIDSCA.AS04`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AS04: Authentication Method - SMS - Use for sign-in. See https://maester.dev/docs/tests/EIDSCA.AS04

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authenticationMeth...| D[Extract Property]
    D -->|includeTargets.isUsableForSignIn| E{Validate Value}
    E -->|Expected: false| F{Return Result}
    F -->|Match| G[Return Pass]
    F -->|No Match| H[Return Fail]
    B -->|Not Connected| I[Skip]
```

## Phase Details

### Phase 1: Prerequisites
- Microsoft Graph connection required

### Phase 2: Data Collection
- **API Endpoint:** `https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')`
- **Property Path:** `includeTargets.isUsableForSignIn`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `includeTargets.isUsableForSignIn` | `-Be` | `false` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAS04Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAS04Compliance.ps1)