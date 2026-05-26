# EIDSCA.AP06: Default Authorization Settings - User can join the tenant by email validation

## Overview

**Check ID:** `AP06`
**Tag:** `EIDSCA.AP06`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AP06: Default Authorization Settings - User can join the tenant by email validation. See https://maester.dev/docs/tests/EIDSCA.AP06

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authorizationPolic...| D[Extract Property]
    D -->|allowEmailVerifiedUsersToJoinOrganization| E{Validate Value}
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
- **Property Path:** `allowEmailVerifiedUsersToJoinOrganization`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `allowEmailVerifiedUsersToJoinOrganization` | `-Be` | `false` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAP06Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAP06Compliance.ps1)