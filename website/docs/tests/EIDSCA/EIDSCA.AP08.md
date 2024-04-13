---
title: EIDSCA.AP08 - Default Authorization Settings - User consent policy assigned for applications
slug: /tests/EIDSCA.AP08
sidebar_class_name: hidden
---

# Default Authorization Settings - User consent policy assigned for applications

Defines if user consent to apps is allowed, and if it is, which app consent policy (permissionGrantPolicy) governs the permissions.

| | |
|-|-|
| **Name** | permissionGrantPolicyIdsAssignedToDefaultUserRole |
| **Control** | Default Authorization Settings |
| **Description** | Manages authorization settings in Azure AD |
| **Severity** | High |

## How to fix
| | |
|-|-|
| **Recommendation** | Microsoft recommends to allow to user consent for apps from verified publisher for selected permissions. CISA SCuBA 2.7 defines that all Non-Admin Users SHALL Be Prevented From Providing Consent To Third-Party Applications. |
| **Configuration** | policies/authorizationPolicy |
| **Setting** | `permissionGrantPolicyIdsAssignedToDefaultUserRole | Sort-Object -Descending | select-object -first 1` |
| **Recommended Value** | 'ManagePermissionGrantsForSelf.microsoft-user-default-low' |
| **Default Value** | ManagePermissionGrantsForSelf.microsoft-user-default-legacy |
| **Graph API Docs** | [authorizationPolicy resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |


## MITRE ATT&CK

```mermaid
mindmap
  root{{MITRE ATT&CK}}
    (Tactic)
      TA0001 - Initial Access - Initial Access
      TA0005 - Defense Evasion - Defense Evasion
      TA0006 - Credential Access - Credential Access
      TA0008 - Lateral Movement - Lateral Movement
    (Mitigation)
      M1017 - User Training
      M1018 - User Account Management
    (Technique)
      T1566.002 - Phishing: Spearphishing Link
      T1078 - Valid Accounts
      T1550 - Use Alternate Authentication Material
      T1528 - Steal Application Access Token
```
|Tactic|Technique|Mitigation|
|---|---|---|
|[TA0001 - Initial Access - Initial Access](https://attack.mitre.org/tactics/TA0001)<br/>[TA0005 - Defense Evasion - Defense Evasion](https://attack.mitre.org/tactics/TA0005)<br/>[TA0006 - Credential Access - Credential Access](https://attack.mitre.org/tactics/TA0006)<br/>[TA0008 - Lateral Movement - Lateral Movement](https://attack.mitre.org/tactics/TA0008)|[T1566.002 - Phishing: Spearphishing Link](https://attack.mitre.org/techniques/T1566/002)<br/>[T1078 - Valid Accounts](https://attack.mitre.org/techniques/T1078)<br/>[T1550 - Use Alternate Authentication Material](https://attack.mitre.org/techniques/T1550)<br/>[T1528 - Steal Application Access Token](https://attack.mitre.org/techniques/T1528)|[M1017 - User Training](https://attack.mitre.org/mitigations/M1017)<br/>[M1018 - User Account Management](https://attack.mitre.org/mitigations/M1018)|

