---
title: EIDSCA.AP10 - Default Authorization Settings - Default User Role Permissions - Allowed to create Apps
slug: /tests/EIDSCA.AP10
sidebar_class_name: hidden
---

# Default Authorization Settings - Default User Role Permissions - Allowed to create Apps

Controls if non-admin users may register custom-developed applications for use within this directory.

| | |
|-|-|
| **Name** | allowedToCreateApps |
| **Control** | Default Authorization Settings |
| **Description** | Manages authorization settings in Azure AD |
| **Severity** | High |

## How to fix
| | |
|-|-|
| **Recommendation** | CISA SCuBA 2.6: Only Administrators SHALL Be Allowed To Register Third-Party Applications |
| **Configuration** | policies/authorizationPolicy |
| **Setting** | `defaultUserRolePermissions.allowedToCreateApps` |
| **Recommended Value** | 'false' |
| **Default Value** | true |
| **Graph API Docs** | [authorizationPolicy resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |
| **Azure Portal** | [View in Azure Portal](https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/UserSettings) | 


