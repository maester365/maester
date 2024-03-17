---
title: Enforce key restrictions (keyRestrictions.isEnforced)
slug: /tests/EIDSCA.authenticationMethodsPolicy.keyRestrictions.isEnforced
sidebar_class_name: hidden
---

# Enforce key restrictions

Manages if registration of FIDO2 keys should be restricted.

| | |
|-|-|
| **Name** | keyRestrictions.isEnforced |
| **Control** | Authentication Method - FIDO2 security key |
| **Description** | Define configuration settings and users or groups that are enabled to use FIDO2 security keys |
| **Severity** | Informational |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2') |
| **Setting** | `keyRestrictions.isEnforced` |
| **Recommended Value** | '' |
| **Default Value** | false |
| **Graph API Docs** | [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/fido2authenticationmethodconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



