# ORCA: Mailbox intelligence based impersonation protection is enabled in anti-phishing policies.

## Overview

**Function Name:** `Test-ORCA115`
**Category:** ORCA
**Test Tag:** `ORCA`

## Description

Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Prerequisites Check}
    B -->|Connection Required| C{Check Connections}
    C -->|Exchange Online, Security & Compliance| D{License Check}
    D -->|No specific license| E[Data Collection]
    E --> F[Compliance Validation]
    F --> G{Return Result}
    G -->|Pass| I[Return True]
    G -->|Fail| J[Return False]
    B -->|Not Connected| K[Return Null - Skipped]
```

## Phase Details

### Phase 1: Prerequisites Check

**Required Connections:**
- Exchange Online
- Security & Compliance

### Phase 2: Data Collection

**Cmdlets/Functions Used:**
- `Get-ORCACollection`

### Phase 3: Compliance Validation

The function validates the collected data against compliance requirements.

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant |
| `$false` | Non-Compliant |
| `$null` | Skipped (missing prerequisites, license, or error) |

## Original Documentation

Mailbox Intelligence Protection enhances impersonation protection for users based on each user's individual sender graph.

#### Remediation action
Enable Mailbox intelligence based impersonation protection in anti-phishing policies.

#### Related Links

* [Microsoft 365 Defender Portal - Anti-phishing](https://security.microsoft.com/antiphishing) 
* [Recommended settings for EOP and Microsoft Defender for Office 365 security](https://aka.ms/orca-atpp-docs-7) 
* [Set up Microsoft Defender for Office 365 anti-phishing and anti-phishing policies](https://aka.ms/orca-atpp-docs-9)

## Standalone Function

See the standalone compliance check function: [`Test-ORCA115Compliance.ps1`](../../standalone-functions/ORCA/Test-ORCA115Compliance.ps1)
