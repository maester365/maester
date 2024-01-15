---
title: AADSC.authorizationPolicy.allowedToCreateApps
description: allowedToCreateApps - Default User Role Permissions - Allowed to create Apps
---

# Default User Role Permissions - Allowed to create Apps

Controls if non-admin users may register custom-developed applications for use within this directory.

| | |
|-|-|
| **Name** | allowedToCreateApps |
| **Control** | Default Authorization Settings |
| **Description** | Manages authorization settings in Azure AD |
| **Severity** | High |

## MITRE ATT&CK

```mermaid
mindmap
  root{{MITRE ATT&CK}}
    (Tactic)
      TA0001 - Initial Access
      TA0005 - Defense Evasion
      TA0006 - Credential Access
      TA0008 - Lateral Movement
    (Mitigation)
      M1017 - User Training
      M1018 - User Account Management
      M1024 - Restrict Registry Permissions
      M1047 - Audit
    (Technique)
      T1566.002 - Phishing: Spearphishing Link
      T1078 - Valid Accounts
      T1550 - Use Alternate Authentication Material
      T1528 - Steal Application Access Token
```

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

