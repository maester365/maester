# EIDSCA.PR03: Default Settings - Password Rule Settings - Enforce custom list

## Overview

**Check ID:** `PR03`
**Tag:** `EIDSCA.PR03`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.PR03: Default Settings - Password Rule Settings - Enforce custom list. See https://maester.dev/docs/tests/EIDSCA.PR03

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/settings...| D[Extract Property]
    D -->|values| E{Validate Value}
    E -->|Expected: True| F{Return Result}
    F -->|Match| G[Return Pass]
    F -->|No Match| H[Return Fail]
    B -->|Not Connected| I[Skip]
```

## Phase Details

### Phase 1: Prerequisites
- Microsoft Graph connection required

### Phase 2: Data Collection
- **API Endpoint:** `https://graph.microsoft.com/beta/settings`
- **Property Path:** `values`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `values` | `-Be` | `True` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaPR03Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaPR03Compliance.ps1)