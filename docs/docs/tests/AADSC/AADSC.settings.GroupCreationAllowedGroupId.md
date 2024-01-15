---
title: AADSC.settings.GroupCreationAllowedGroupId
description: GroupCreationAllowedGroupId - M365 groups - Allow group created for a specific security group
---

# M365 groups - Allow group created for a specific security group

GUID of the security group for which the members are allowed to create Microsoft 365 groups even when EnableGroupCreation == false.

| | |
|-|-|
| **Name** | GroupCreationAllowedGroupId |
| **Control** | Default Settings - Classification and M365 Groups |
| **Description** | Define group configurations that can be used to customize the tenant-wide and object-specific restrictions and allowed behavior |
| **Severity** | Informational |



## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | settings |
| **Setting** | `GroupCreationAllowedGroupId` |
| **Recommended Value** | '' |
| **Default Value** |  |
| **Graph API Docs** | [directorySetting resource type - Microsoft Graph beta - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |


