# EIDSCA.AM03: Authentication Method - Microsoft Authenticator - Require number matching for push notifications

## Overview

**Check ID:** `AM03`
**Tag:** `EIDSCA.AM03`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AM03: Authentication Method - Microsoft Authenticator - Require number matching for push notifications. See https://maester.dev/docs/tests/EIDSCA.AM03

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authenticationMeth...| D[Extract Property]
    D -->|featureSettings.numberMatchingRequiredState.state| E{Validate Value}
    E -->|Expected: enabled| F{Return Result}
    F -->|Match| G[Return Pass]
    F -->|No Match| H[Return Fail]
    B -->|Not Connected| I[Skip]
```

## Phase Details

### Phase 1: Prerequisites
- Microsoft Graph connection required

### Phase 2: Data Collection
- **API Endpoint:** `https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')`
- **Property Path:** `featureSettings.numberMatchingRequiredState.state`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `featureSettings.numberMatchingRequiredState.state` | `-Be` | `enabled` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAM03Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAM03Compliance.ps1)