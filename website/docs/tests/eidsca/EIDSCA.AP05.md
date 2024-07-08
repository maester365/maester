---
title: EIDSCA.AP05 - Default Authorization Settings - Sign-up for email based subscription
slug: /tests/EIDSCA.AP05
sidebar_class_name: hidden
---

# Default Authorization Settings - Sign-up for email based subscription

Indicates whether users can sign up for email based subscriptions.

| | |
|-|-|
| **Name** | allowedToSignUpEmailBasedSubscriptions |
| **Control** | Default Authorization Settings |
| **Description** | Manages authorization settings in Azure AD |
| **Severity** | Medium |

## How to fix



### Details of configuration item
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authorizationPolicy |
| **Setting** | `allowedToSignUpEmailBasedSubscriptions` |
| **Recommended Value** | 'false' |
| **Default Value** | true |
| **Graph API Docs** | [authorizationPolicy resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |


## MITRE ATT&CK

```mermaid
mindmap
  root{{MITRE ATT&CK}}
    (Tactic)
      TA0001 - Initial Access - Initial Access
    (Mitigation)

    (Technique)

```
|Tactic|Technique|Mitigation|
|---|---|---|
|[TA0001 - Initial Access - Initial Access](https://attack.mitre.org/tactics/TA0001)|||

