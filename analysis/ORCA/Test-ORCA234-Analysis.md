# ORCA: Click through is disabled for Safe Documents.

## Overview

**Function Name:** `Test-ORCA234`
**Category:** ORCA
**Test Tag:** `ORCA`

## Description

Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

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

Safe Documents can assist protecting files opened in Office appplications. Before a user is allowed to trust a file opened in Office 365 ProPlus using Protected View, the file will be verified by Microsoft Defender for Office 365. It is possible to allow users click through Protected View even if Safe Documents identified the file as malicious. It is recommended to configure Safe Documents to not let users click through Pretected View.

#### Remediation action
Do not let usres click through Protected View if Safe Documents identified the file as malicious.

#### Related Links

* [Microsoft 365 Defender Portal - Safe attachments](https://security.microsoft.com/safeattachmentv2) 
* [Recommended settings for EOP and Microsoft Defender for Office 365](https://aka.ms/orca-atpp-docs-7) 
* [Safe Documents in Microsoft 365 E5](https://aka.ms/orca-atpp-docs-1)

## Standalone Function

See the standalone compliance check function: [`Test-ORCA234Compliance.ps1`](../../standalone-functions/ORCA/Test-ORCA234Compliance.ps1)
