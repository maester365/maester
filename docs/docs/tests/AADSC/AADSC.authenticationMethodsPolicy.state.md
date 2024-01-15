---
title: AADSC.authenticationMethodsPolicy.state
description: state - State
---

# State

Whether the CBA is enabled in the tenant.

| | |
|-|-|
| **Name** | state |
| **Control** | Authentication Method - Certificate-based authentication |
| **Description** | Define configuration settings and users or groups that are enabled to use certificate-based authentication. |
| **Severity** | High |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate') |
| **Setting** | `state` |
| **Recommended Value** | '' |
| **Default Value** | disabled |
| **Graph API Docs** | [certificateBasedAuthConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/certificatebasedauthconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



