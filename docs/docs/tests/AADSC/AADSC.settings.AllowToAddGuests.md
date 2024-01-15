---
title: AADSC.settings.AllowToAddGuests
description: AllowToAddGuests - M365 groups - Allow to add Guests
---

# M365 groups - Allow to add Guests

A boolean indicating whether or not is allowed to add guests to this directory. This setting may be overridden and become read-only if EnableMIPLabels is set to True and a guest policy is associated with the sensitivity label assigned to the group. If the AllowToAddGuests setting is set to False at the organization level, any AllowToAddGuests setting at the group level is ignored. If you want to enable guest access for only a few groups, you must set AllowToAddGuests to be true at the organization level, and then selectively disable it for specific groups.

| | |
|-|-|
| **Name** | AllowToAddGuests |
| **Control** | Default Settings - Classification and M365 Groups |
| **Description** | Define group configurations that can be used to customize the tenant-wide and object-specific restrictions and allowed behavior |
| **Severity** | Medium |



## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | settings |
| **Setting** | `AllowToAddGuests` |
| **Recommended Value** | '' |
| **Default Value** | True |
| **Graph API Docs** | [directorySetting resource type - Microsoft Graph beta - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |


