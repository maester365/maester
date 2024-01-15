---
title: AADSC.authenticationMethodsPolicy.isUsableOnce
description: isUsableOnce - One-time
---

# One-time

Determines whether the pass is limited to a one-time use.

| | |
|-|-|
| **Name** | isUsableOnce |
| **Control** | Authentication Method - Temporary Access Pass |
| **Description** | Define configuration settings and users or groups that are enabled to use Temporary Access Pass |
| **Severity** | Medium |



## How to fix
| | |
|-|-|
| **Recommendation** | Avoid to allow reusable passes and restrict usage to one-time use (if applicable) |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass') |
| **Setting** | `isUsableOnce` |
| **Recommended Value** | 'false' |
| **Default Value** | false |
| **Graph API Docs** | [temporaryAccessPassAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/temporaryaccesspassauthenticationmethodconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |


