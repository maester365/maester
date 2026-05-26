# EIDSCA.CR01: Consent Framework - Admin Consent Request - Policy to enable or disable admin consent request feature

## Overview

**Check ID:** `CR01`
**Tag:** `EIDSCA.CR01`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.CR01: Consent Framework - Admin Consent Request - Policy to enable or disable admin consent request feature. See https://maester.dev/docs/tests/EIDSCA.CR01

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/adminConsentReques...| D[Extract Property]
    D -->|isEnabled| E{Validate Value}
    E -->|Expected: true| F{Return Result}
    F -->|Match| G[Return Pass]
    F -->|No Match| H[Return Fail]
    B -->|Not Connected| I[Skip]
```

## Phase Details

### Phase 1: Prerequisites
- Microsoft Graph connection required

### Phase 2: Data Collection
- **API Endpoint:** `https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy`
- **Property Path:** `isEnabled`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `isEnabled` | `-Be` | `true` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaCR01Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaCR01Compliance.ps1)