# Test-MtPrivPermanentDirectoryRole: 

## Overview

**Function Name:** `Test-MtPrivPermanentDirectoryRole`
**Category:** Maester/Entra

## Description



## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Prerequisites Check}
    B --> C{License Check}
    C -->|No specific license| D[Data Collection]
    D --> E[Compliance Validation]
    E --> F{Return Result}
    F -->|Pass| I[Return True]
    F -->|Fail| J[Return False]
    B -->|Not Connected| K[Return Null - Skipped]
```

## Phase Details

### Phase 1: Prerequisites Check

No specific prerequisites required.

### Phase 2: Data Collection

**Graph API Calls:**
- `roleManagement/directory/roleAssignments?$expand=principal`
- `roleManagement/directory/roleDefinitions`

**Cmdlets/Functions Used:**
- `Get-MgContext`
- `Invoke-MtGraphRequest`
- `Invoke-WebRequest`

### Phase 3: Compliance Validation

**Properties Checked:**

| Property | Expected Value |
| --- | --- |
| `capabilityStatus` | `Enabled` |
| `service` | `exchange` |
| `templateId` | `$PermDirRoleAssignment.roleDefinitionId` |

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant |
| `$false` | Non-Compliant |
| `$null` | Skipped (missing prerequisites, license, or error) |

## Standalone Function

See the standalone compliance check function: [`Test-MtPrivPermanentDirectoryRoleCompliance.ps1`](../../standalone-functions/Maester/Entra/Test-MtPrivPermanentDirectoryRoleCompliance.ps1)
