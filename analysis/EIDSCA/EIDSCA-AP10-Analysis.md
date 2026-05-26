# EIDSCA.AP10: Default Authorization Settings - Default User Role Permissions - Allowed to create Apps

## Overview

**Check ID:** `AP10`
**Tag:** `EIDSCA.AP10`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AP10: Default Authorization Settings - Default User Role Permissions - Allowed to create Apps. See https://maester.dev/docs/tests/EIDSCA.AP10

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authorizationPolic...| D[Extract Property]
    D -->|defaultUserRolePermissions.allowedToCreateApps| E{Validate Value}
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
- **Property Path:** `defaultUserRolePermissions.allowedToCreateApps`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `defaultUserRolePermissions.allowedToCreateApps` | `-Be` | `false` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAP10Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAP10Compliance.ps1)