# EIDSCA.CR04: Consent Framework - Admin Consent Request - Consent request duration (days)

## Overview

**Check ID:** `CR04`
**Tag:** `EIDSCA.CR04`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.CR04: Consent Framework - Admin Consent Request - Consent request duration (days). See https://maester.dev/docs/tests/EIDSCA.CR04

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/adminConsentReques...| D[Extract Property]
    D -->|requestDurationInDays| E{Validate Value}
    E -->|Expected: 30| F{Return Result}
    F -->|Match| G[Return Pass]
    F -->|No Match| H[Return Fail]
    B -->|Not Connected| I[Skip]
```

## Phase Details

### Phase 1: Prerequisites
- Microsoft Graph connection required

### Phase 2: Data Collection
- **API Endpoint:** `https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy`
- **Property Path:** `requestDurationInDays`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `requestDurationInDays` | `-BeLessOrEqual` | `30` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaCR04Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaCR04Compliance.ps1)