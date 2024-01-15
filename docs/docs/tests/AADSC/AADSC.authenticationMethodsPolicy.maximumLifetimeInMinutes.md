---
title: AADSC.authenticationMethodsPolicy.maximumLifetimeInMinutes
description: maximumLifetimeInMinutes - Maximum lifetime
---

# Maximum lifetime

Maximum lifetime in minutes for any Temporary Access Pass created in the tenant. Value can be between 10 and 43200 minutes (equivalent to 30 days).

| | |
|-|-|
| **Name** | maximumLifetimeInMinutes |
| **Control** | Authentication Method - Temporary Access Pass |
| **Description** | Define configuration settings and users or groups that are enabled to use Temporary Access Pass |
| **Severity** | High |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass') |
| **Setting** | `maximumLifetimeInMinutes` |
| **Recommended Value** | '' |
| **Default Value** | 480 |
| **Graph API Docs** | [temporaryAccessPassAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/temporaryaccesspassauthenticationmethodconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



