# EIDSCA.AP08: Default Authorization Settings - User consent policy assigned for applications

## Overview

**Check ID:** `AP08`
**Tag:** `EIDSCA.AP08`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AP08: Default Authorization Settings - User consent policy assigned for applications. See https://maester.dev/docs/tests/EIDSCA.AP08

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authorizationPolic...| D[Extract Property]
    D -->|permissionGrantPolicyIdsAssignedToDefaultUserRole| E{Validate Value}
    E -->|Expected: ManagePermissionGrantsForSelf.microsoft-user-default-low| F{Return Result}
    F -->|Match| G[Return Pass]
    F -->|No Match| H[Return Fail]
    B -->|Not Connected| I[Skip]
```

## Phase Details

### Phase 1: Prerequisites
- Microsoft Graph connection required

### Phase 2: Data Collection
- **API Endpoint:** `https://graph.microsoft.com/beta/policies/authorizationPolicy`
- **Property Path:** `permissionGrantPolicyIdsAssignedToDefaultUserRole`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `permissionGrantPolicyIdsAssignedToDefaultUserRole` | `-Be` | `ManagePermissionGrantsForSelf.microsoft-user-default-low` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAP08Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAP08Compliance.ps1)