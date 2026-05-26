# EIDSCA.CP04: Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to

## Overview

**Check ID:** `CP04`
**Tag:** `EIDSCA.CP04`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.CP04: Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to. See https://maester.dev/docs/tests/EIDSCA.CP04

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/settings...| D[Extract Property]
    D -->|values| E{Validate Value}
    E -->|Expected: true| F{Return Result}
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
| `values` | `-Be` | `true` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaCP04Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaCP04Compliance.ps1)