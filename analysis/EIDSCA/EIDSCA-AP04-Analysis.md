# EIDSCA.AP04: Default Authorization Settings - Guest invite restrictions

## Overview

**Check ID:** `AP04`
**Tag:** `EIDSCA.AP04`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AP04: Default Authorization Settings - Guest invite restrictions. See https://maester.dev/docs/tests/EIDSCA.AP04

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authorizationPolic...| D[Extract Property]
    D -->|allowInvitesFrom| E{Validate Value}
    E -->|Expected: @('adminsAndGuestInviters','none')| F{Return Result}
    F -->|Match| G[Return Pass]
    F -->|No Match| H[Return Fail]
    B -->|Not Connected| I[Skip]
```

## Phase Details

### Phase 1: Prerequisites
- Microsoft Graph connection required

### Phase 2: Data Collection
- **API Endpoint:** `https://graph.microsoft.com/beta/policies/authorizationPolicy`
- **Property Path:** `allowInvitesFrom`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `allowInvitesFrom` | `-BeIn` | `@('adminsAndGuestInviters','none')` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAP04Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAP04Compliance.ps1)