# EIDSCA.AP07: Default Authorization Settings - Guest user access

## Overview

**Check ID:** `AP07`
**Tag:** `EIDSCA.AP07`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AP07: Default Authorization Settings - Guest user access. See https://maester.dev/docs/tests/EIDSCA.AP07

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authorizationPolic...| D[Extract Property]
    D -->|guestUserRoleId| E{Validate Value}
    E -->|Expected: 2af84b1e-32c8-42b7-82bc-daa82404023b| F{Return Result}
    F -->|Match| G[Return Pass]
    F -->|No Match| H[Return Fail]
    B -->|Not Connected| I[Skip]
```

## Phase Details

### Phase 1: Prerequisites
- Microsoft Graph connection required

### Phase 2: Data Collection
- **API Endpoint:** `https://graph.microsoft.com/beta/policies/authorizationPolicy`
- **Property Path:** `guestUserRoleId`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `guestUserRoleId` | `-Be` | `2af84b1e-32c8-42b7-82bc-daa82404023b` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAP07Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAP07Compliance.ps1)