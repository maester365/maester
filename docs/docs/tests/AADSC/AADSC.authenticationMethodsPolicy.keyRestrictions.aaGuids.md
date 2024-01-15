---
title: AADSC.authenticationMethodsPolicy.keyRestrictions.aaGuids
description: keyRestrictions.aaGuids - Restricted
---

# Restricted

You can work with your Security key provider to determine the AAGuids of their devices for allowing or blocking usage.

| | |
|-|-|
| **Name** | keyRestrictions.aaGuids |
| **Control** | Authentication Method - FIDO2 security key |
| **Description** | Define configuration settings and users or groups that are enabled to use FIDO2 security keys |
| **Severity** | Informational |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2') |
| **Setting** | `keyRestrictions.aaGuids` |
| **Recommended Value** | '' |
| **Default Value** |  |
| **Graph API Docs** | [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/fido2authenticationmethodconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



