---
title: EIDSCA.PR02 - Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory
slug: /tests/EIDSCA.PR02
sidebar_class_name: hidden
---

# Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory

If set to Yes, password protection is turned on for Active Directory domain controllers when the appropriate agent is installed.

| | |
|-|-|
| **Name** | EnableBannedPasswordCheckOnPremises |
| **Control** | Default Settings - Password Rule Settings |
| **Description** | Define the password protection and Smart Lockout configurations that can be used to customize the tenant-wide and object-specific restrictions and allowed behavior |
| **Severity** | High |

## How to fix



### Details of configuration item
| | |
|-|-|
| **Recommendation** | [Azure identity & access security best practices - Microsoft Learn](https://learn.microsoft.com/en-us/azure/security/fundamentals/identity-management-best-practices#enable-password-management) |
| **Configuration** | settings |
| **Setting** | `values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value` |
| **Recommended Value** | 'True' |
| **Default Value** | False |
| **Graph API Docs** | [directorySetting resource type - Microsoft Graph beta - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |


## MITRE ATT&CK

```mermaid
mindmap
  root{{MITRE ATT&CK}}
    (Tactic)
      TA0006 - Credential Access - Credential Access
    (Mitigation)
      M1018 - User Account Management
      M1027 - Password Policies
    (Technique)
      T1110 - Brute Force
```
|Tactic|Technique|Mitigation|
|---|---|---|
|[TA0006 - Credential Access - Credential Access](https://attack.mitre.org/tactics/TA0006)|[T1110 - Brute Force](https://attack.mitre.org/techniques/T1110)|[M1018 - User Account Management](https://attack.mitre.org/mitigations/M1018)<br/>[M1027 - Password Policies](https://attack.mitre.org/mitigations/M1027)|

