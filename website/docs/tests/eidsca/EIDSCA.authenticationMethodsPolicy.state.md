---
title: State (state)
slug: /tests/EIDSCA.authenticationMethodsPolicy.state
sidebar_class_name: hidden
---

# State

Whether the Voice call is enabled in the tenant.

| | |
|-|-|
| **Name** | state |
| **Control** | Authentication Method - Voice call |
| **Description** | Define configuration settings and users or groups that are enabled to use voice call for authentication. Voice call is not usable as a first-factor authentication method. |
| **Severity** | High |

## How to fix
| | |
|-|-|
| **Recommendation** | Choose authentication methods with number matching (Authenticator)  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice') |
| **Setting** | `state` |
| **Recommended Value** | 'disabled' |
| **Default Value** | disabled |
| **Graph API Docs** |  |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



