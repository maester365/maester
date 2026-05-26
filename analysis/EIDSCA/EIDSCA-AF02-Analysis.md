# EIDSCA.AF02: Authentication Method - FIDO2 security key - Allow self-service set up

## Overview

**Check ID:** `AF02`
**Tag:** `EIDSCA.AF02`
**Category:** EIDSCA (Entra ID Security Configuration Analyzer)

## Description

EIDSCA.AF02: Authentication Method - FIDO2 security key - Allow self-service set up. See https://maester.dev/docs/tests/EIDSCA.AF02

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Check Graph Connection}
    B -->|Connected| C[Query Graph API]
    C -->|GET https://graph.microsoft.com/beta/policies/authenticationMeth...| D[Extract Property]
    D -->|isSelfServiceRegistrationAllowed| E{Validate Value}
    E -->|Expected: true| F{Return Result}
    F -->|Match| G[Return Pass]
    F -->|No Match| H[Return Fail]
    B -->|Not Connected| I[Skip]
```

## Phase Details

### Phase 1: Prerequisites
- Microsoft Graph connection required

### Phase 2: Data Collection
- **API Endpoint:** `https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')`
- **Property Path:** `isSelfServiceRegistrationAllowed`

### Phase 3: Compliance Validation

| Property | Comparison | Expected Value |
| --- | --- | --- |
| `isSelfServiceRegistrationAllowed` | `-Be` | `true` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant - Configuration matches expected value |
| `$false` | Non-Compliant - Configuration does not match |
| `$null` | Skipped - Not connected or prerequisite not met |

## Standalone Function

See: [`Test-EidscaAF02Compliance.ps1`](../../standalone-functions/EIDSCA/Test-EidscaAF02Compliance.ps1)