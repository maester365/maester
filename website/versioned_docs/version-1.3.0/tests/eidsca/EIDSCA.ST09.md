---
title: EIDSCA.ST09 - Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content
slug: /tests/EIDSCA.ST09
sidebar_class_name: hidden
---

# Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content

Indicating whether or not a guest user can have access to Microsoft 365 groups content. This setting does not require an Azure Active Directory Premium P1 license.

| | |
|-|-|
| **Name** | AllowGuestsToAccessGroups |
| **Control** | Default Settings - Classification and M365 Groups |
| **Description** | Define group configurations that can be used to customize the tenant-wide and object-specific restrictions and allowed behavior |
| **Severity** | Medium |

## How to fix

[Microsoft Learn - Microsoft Entra cmdlets for configuring group settings](https://learn.microsoft.com/en-us/entra/identity/users/groups-settings-cmdlets#update-settings-at-the-directory-level)

### Details of configuration item
| | |
|-|-|
| **Recommendation** | Manages if guest accounts can access resources through Microsoft 365 Group membership and could break collaboration if you disable it. |
| **Configuration** | settings |
| **Setting** | `values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value` |
| **Recommended Value** | 'True' |
| **Default Value** | True |
| **Graph API Docs** | [directorySetting resource type - Microsoft Graph beta - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



