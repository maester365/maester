---
title: AADSC.authorizationPolicy.blockMsolPowerShell
description: blockMsolPowerShell - Blocked MSOnline PowerShell access
---

# Blocked MSOnline PowerShell access

Specifies whether the user-based access to the legacy service endpoint used by MSOL PowerShell is blocked or not. This does not affect Azure AD Connect or Microsoft Graph.

| | |
|-|-|
| **Name** | blockMsolPowerShell |
| **Control** | Default Authorization Settings |
| **Description** | Manages authorization settings in Azure AD |
| **Severity** | Medium |



## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authorizationPolicy |
| **Setting** | `blockMsolPowerShell` |
| **Recommended Value** | '' |
| **Default Value** | false |
| **Graph API Docs** | [authorizationPolicy resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |


