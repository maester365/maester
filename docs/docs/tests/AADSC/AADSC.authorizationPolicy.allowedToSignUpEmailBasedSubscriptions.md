---
title: AADSC.authorizationPolicy.allowedToSignUpEmailBasedSubscriptions
description: allowedToSignUpEmailBasedSubscriptions - Sign-up for email based subscription
---

# Sign-up for email based subscription

Indicates whether users can sign up for email based subscriptions.

| | |
|-|-|
| **Name** | allowedToSignUpEmailBasedSubscriptions |
| **Control** | Default Authorization Settings |
| **Description** | Manages authorization settings in Azure AD |
| **Severity** | Medium |

## MITRE ATT&CK

```mermaid
mindmap
  root{{MITRE ATT&CK}}
    (Tactic)
      TA0001 - Initial Access
    (Mitigation)

    (Technique)

```

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authorizationPolicy |
| **Setting** | `allowedToSignUpEmailBasedSubscriptions` |
| **Recommended Value** | 'false' |
| **Default Value** | true |
| **Graph API Docs** | [authorizationPolicy resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |


