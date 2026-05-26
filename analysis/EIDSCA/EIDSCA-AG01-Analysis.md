# EIDSCA.AG01: Authentication Method - General Settings - Manage migration

## Overview

**Check ID:** `AG01`
**Tag:** `EIDSCA.AG01`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AG01: Authentication Method - General Settings - Manage migration. See https://maester.dev/docs/tests/EIDSCA.AG01

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authenticationMeth...| D[Extract Property]
    D -->|policyMigrationState| E{Validate Value}
    E -->|Expected: @('migrationComplete', '')| F{Return Result}
    F -->|Match| G[Return Pass]
    F -->|No Match| H[Return Fail]
    B -->|Not Connected| I[Skip]
```

## Phase Details

### Phase 1: Prerequisites
- Microsoft Graph connection required

### Phase 2: Data Collection
- **API Endpoint:** `https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy`
- **Property Path:** `policyMigrationState`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `policyMigrationState` | `-BeIn` | `@('migrationComplete', '')` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAG01Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAG01Compliance.ps1)