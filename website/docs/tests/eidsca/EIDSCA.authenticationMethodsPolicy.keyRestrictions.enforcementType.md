---
title: Restrict specific keys (keyRestrictions.enforcementType)
slug: /tests/EIDSCA.authenticationMethodsPolicy.keyRestrictions.enforcementType
sidebar_class_name: hidden
---

# Restrict specific keys

Defines if list of AADGUID will be used to allow or block registration.

| | |
|-|-|
| **Name** | keyRestrictions.enforcementType |
| **Control** | Authentication Method - FIDO2 security key |
| **Description** | Define configuration settings and users or groups that are enabled to use FIDO2 security keys |
| **Severity** | High |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2') |
| **Setting** | `keyRestrictions.enforcementType` |
| **Recommended Value** | 'block' |
| **Default Value** | block |
| **Graph API Docs** | [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/fido2authenticationmethodconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



