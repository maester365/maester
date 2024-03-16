---
title: EIDSCA.authorizationPolicy.allowedToCreateTenants
description: allowedToCreateTenants - Default User Role Permissions - Allowed to create Tenants
slug: /tests/EIDSCA.authorizationPolicy.allowedToCreateTenants
---

# Default User Role Permissions - Allowed to create Tenants

Restricts the creation of Azure AD tenants to the global administrator or tenant creator roles. Anyone who creates a tenant will become the global administrator for that tenant.

| | |
|-|-|
| **Name** | allowedToCreateTenants |
| **Control** | Default Authorization Settings |
| **Description** | Manages authorization settings in Azure AD |
| **Severity** | Medium |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authorizationPolicy |
| **Setting** | `allowedToCreateTenants` |
| **Recommended Value** | '' |
| **Default Value** | true |
| **Graph API Docs** | [authorizationPolicy resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |
| **Azure Portal** | [View in Azure Portal](https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/UserSettings) | 

## MITRE ATT&CK

```mermaid
mindmap
  root{{MITRE ATT&CK}}
    (Tactic)
      TA0010 - Exfiltration - Exfiltration
      TA0040 - Impact - Impact
    (Mitigation)

    (Technique)

```
|Tactic|Technique|Mitigation|
|---|---|---|
|[TA0010 - Exfiltration - Exfiltration](https://attack.mitre.org/tactics/TA0010)<br/>[TA0040 - Impact - Impact](https://attack.mitre.org/tactics/TA0040)|||

