# EIDSCA.CR02: Consent Framework - Admin Consent Request - Reviewers will receive email notifications for requests

## Overview

**Check ID:** `CR02`
**Tag:** `EIDSCA.CR02`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.CR02: Consent Framework - Admin Consent Request - Reviewers will receive email notifications for requests. See https://maester.dev/docs/tests/EIDSCA.CR02

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/adminConsentReques...| D[Extract Property]
    D -->|notifyReviewers| E{Validate Value}
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
- **Property Path:** `notifyReviewers`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `notifyReviewers` | `-Be` | `true` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaCR02Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaCR02Compliance.ps1)