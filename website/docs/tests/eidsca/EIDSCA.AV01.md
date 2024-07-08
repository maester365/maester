---
title: EIDSCA.AV01 - Authentication Method - Voice call - State
slug: /tests/EIDSCA.AV01
sidebar_class_name: hidden
---

# Authentication Method - Voice call - State

Whether the Voice call is enabled in the tenant.

| | |
|-|-|
| **Name** | state |
| **Control** | Authentication Method - Voice call |
| **Description** | Define configuration settings and users or groups that are enabled to use voice call for authentication. Voice call is not usable as a first-factor authentication method. |
| **Severity** | High |

## How to fix



### Details of configuration item
| | |
|-|-|
| **Recommendation** | Choose authentication methods with number matching (Authenticator)  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice') |
| **Setting** | `state` |
| **Recommended Value** | 'disabled' |
| **Default Value** | disabled |
| **Graph API Docs** |  |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



