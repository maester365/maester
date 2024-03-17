---
title: Included users/groups from CBA (includeTargets)
slug: /tests/EIDSCA.authenticationMethodsPolicy.includeTargets
sidebar_class_name: hidden
---

# Included users/groups from CBA

Object Id or scope of users which will be able to use CBA and determines whether the user is enforced to register the authentication method.

| | |
|-|-|
| **Name** | includeTargets |
| **Control** | Authentication Method - Certificate-based authentication |
| **Description** | Define configuration settings and users or groups that are enabled to use certificate-based authentication. |
| **Severity** | Medium |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate') |
| **Setting** | `includeTargets` |
| **Recommended Value** | '' |
| **Default Value** |  |
| **Graph API Docs** | [certificateBasedAuthConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/certificatebasedauthconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



