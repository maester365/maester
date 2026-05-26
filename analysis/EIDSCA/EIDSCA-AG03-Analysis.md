# EIDSCA.AG03: Authentication Method - General Settings - Report suspicious activity - Included users/groups

## Overview

**Check ID:** `AG03`
**Tag:** `EIDSCA.AG03`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AG03: Authentication Method - General Settings - Report suspicious activity - Included users/groups. See https://maester.dev/docs/tests/EIDSCA.AG03

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authenticationMeth...| D[Extract Property]
    D -->|reportSuspiciousActivitySettings.includeTarget.id| E{Validate Value}
    E -->|Expected: all_users| F{Return Result}
    F -->|Match| G[Return Pass]
    F -->|No Match| H[Return Fail]
    B -->|Not Connected| I[Skip]
```

## Phase Details

### Phase 1: Prerequisites
- Microsoft Graph connection required

### Phase 2: Data Collection
- **API Endpoint:** `https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy`
- **Property Path:** `reportSuspiciousActivitySettings.includeTarget.id`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `reportSuspiciousActivitySettings.includeTarget.id` | `-Be` | `all_users` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAG03Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAG03Compliance.ps1)