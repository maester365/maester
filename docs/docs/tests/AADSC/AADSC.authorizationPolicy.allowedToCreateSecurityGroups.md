---
title: AADSC.authorizationPolicy.allowedToCreateSecurityGroups
description: allowedToCreateSecurityGroups - Default User Role Permissions - Allowed to create Security Groups
---

# Default User Role Permissions - Allowed to create Security Groups

Defines default permission of user to create security groups in Azure portals, API or PowerShell. Global administrators and user administrators can still create security groups.

| | |
|-|-|
| **Name** | allowedToCreateSecurityGroups |
| **Control** | Default Authorization Settings |
| **Description** | Manages authorization settings in Azure AD |
| **Severity** | Informational |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authorizationPolicy |
| **Setting** | `allowedToCreateSecurityGroups` |
| **Recommended Value** | '' |
| **Default Value** | true |
| **Graph API Docs** | [authorizationPolicy resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |
| **Azure Portal** | [View in Azure Portal](https://portal.azure.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/General) | 

## MITRE ATT&CK

```mermaid
mindmap
  root{{MITRE ATT&CK}}
    (Tactic)
      TA0003 - Persistence - Persistence
    (Mitigation)

    (Technique)

```
|Tactic|Technique|Mitigation|
|---|---|---|
|[TA0003 - Persistence - Persistence](https://attack.mitre.org/tactics/TA0003)|||

