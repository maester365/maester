---
title: M365 groups naming convention - Classification descriptions (ClassificationDescriptions)
slug: /tests/EIDSCA.settings.ClassificationDescriptions
sidebar_class_name: hidden
---

# M365 groups naming convention - Classification descriptions

A comma-delimited list of classification descriptions. This setting does not apply when EnableMIPLabels == True. Character limit for property ClassificationDescriptions is 300, and commas can't be escaped.

| | |
|-|-|
| **Name** | ClassificationDescriptions |
| **Control** | Default Settings - Classification and M365 Groups |
| **Description** | Define group configurations that can be used to customize the tenant-wide and object-specific restrictions and allowed behavior |
| **Severity** | Informational |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | settings |
| **Setting** | `ClassificationDescriptions` |
| **Recommended Value** | '' |
| **Default Value** |  |
| **Graph API Docs** | [directorySetting resource type - Microsoft Graph beta - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



