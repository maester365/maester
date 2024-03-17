---
title: M365 groups - Allow Guests to become Group Owner (AllowGuestsToBeGroupOwner)
slug: /tests/EIDSCA.settings.AllowGuestsToBeGroupOwner
---

# M365 groups - Allow Guests to become Group Owner

Indicating whether or not a guest user can be an owner of groups

| | |
|-|-|
| **Name** | AllowGuestsToBeGroupOwner |
| **Control** | Default Settings - Classification and M365 Groups |
| **Description** | Define group configurations that can be used to customize the tenant-wide and object-specific restrictions and allowed behavior |
| **Severity** | Medium |

## How to fix
| | |
|-|-|
| **Recommendation** | CISA SCuBA 2.18: Guest users SHOULD have limited access to Azure AD directory objects |
| **Configuration** | settings |
| **Setting** | `AllowGuestsToBeGroupOwner` |
| **Recommended Value** | 'false' |
| **Default Value** | false |
| **Graph API Docs** | [directorySetting resource type - Microsoft Graph beta - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



