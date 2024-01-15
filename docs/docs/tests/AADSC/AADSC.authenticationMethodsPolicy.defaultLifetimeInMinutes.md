---
title: AADSC.authenticationMethodsPolicy.defaultLifetimeInMinutes
description: defaultLifetimeInMinutes - Default lifetime
---

# Default lifetime

Default lifetime in minutes for creating a new Temporary Access Pass.

| | |
|-|-|
| **Name** | defaultLifetimeInMinutes |
| **Control** | Authentication Method - Temporary Access Pass |
| **Description** | Define configuration settings and users or groups that are enabled to use Temporary Access Pass |
| **Severity** | High |



## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass') |
| **Setting** | `defaultLifetimeInMinutes` |
| **Recommended Value** | '' |
| **Default Value** | 60 |
| **Graph API Docs** | [temporaryAccessPassAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/temporaryaccesspassauthenticationmethodconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |


