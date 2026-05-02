---
title: EIDSCA.AF05 - Authentication Method - FIDO2 security key - Restricted
slug: /tests/EIDSCA.AF05
sidebar_class_name: hidden
---

# Authentication Method - FIDO2 security key - Restricted

You can work with your Security key provider to determine the AAGuids of their devices for allowing or blocking usage.

| | |
|-|-|
| **Name** | keyRestrictions.aaGuids |
| **Control** | Authentication Method - FIDO2 security key |
| **Description** | Define configuration settings and users or groups that are enabled to use FIDO2 security keys |
| **Severity** | Low |

## How to fix

[Microsoft Learn - Enable passkeys (FIDO2) for your organization: Restricted AAGUIDS](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-enable-passkey-fido2#passkey-optional-settings)

### Details of configuration item
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2') |
| **Setting** | `keyRestrictions.aaGuids -notcontains $null` |
| **Recommended Value** | 'true' |
| **Default Value** |  |
| **Graph API Docs** | [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/fido2authenticationmethodconfiguration) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



