# EIDSCA.AM09: Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications

## Overview

**Check ID:** `AM09`
**Tag:** `EIDSCA.AM09`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AM09: Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.AM09

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authenticationMeth...| D[Extract Property]
    D -->|featureSettings.displayLocationInformationRequiredState.state| E{Validate Value}
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
- **Property Path:** `featureSettings.displayLocationInformationRequiredState.state`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `featureSettings.displayLocationInformationRequiredState.state` | `-Be` | `enabled` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAM09Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAM09Compliance.ps1)