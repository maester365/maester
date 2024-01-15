---
title: AADSC.settings.NewUnifiedGroupWritebackDefault
description: NewUnifiedGroupWritebackDefault - Default writeback setting for newly created Microsoft 365 groups
---

# Default writeback setting for newly created Microsoft 365 groups

If the original version of group write-back is already enabled and in use in your environment, all your Microsoft 365 groups have already been written back to Active Directory. Instead of disabling all Microsoft 365 groups, review any use of the previously written-back groups. Disable only those that are no longer needed in on-premises Active Directory.

| | |
|-|-|
| **Name** | NewUnifiedGroupWritebackDefault |
| **Control** | Default Settings - Classification and M365 Groups |
| **Description** | Define group configurations that can be used to customize the tenant-wide and object-specific restrictions and allowed behavior |
| **Severity** | Informational |

## How to fix
| | |
|-|-|
| **Recommendation** | [Modify group writeback in Microsoft Entra Connect - Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/en-us/azure/active-directory/hybrid/how-to-connect-modify-group-writeback#disable-automatic-writeback-of-new-microsoft-365-groups) |
| **Configuration** | settings |
| **Setting** | `NewUnifiedGroupWritebackDefault` |
| **Recommended Value** | '' |
| **Default Value** | true |
| **Graph API Docs** | [directorySetting resource type - Microsoft Graph beta - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



