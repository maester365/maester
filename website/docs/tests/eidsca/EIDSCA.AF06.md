---
title: EIDSCA.AF06 - Authentication Method - FIDO2 security key - Restrict specific keys
slug: /tests/EIDSCA.AF06
sidebar_class_name: hidden
---

# Authentication Method - FIDO2 security key - Restrict specific keys

Defines if list of AADGUID will be used to allow or block registration.

| | |
|-|-|
| **Name** | keyRestrictions.enforcementType |
| **Control** | Authentication Method - FIDO2 security key |
| **Description** | Define configuration settings and users or groups that are enabled to use FIDO2 security keys |
| **Severity** | High |

## How to fix

[Microsoft Learn - Enable passkeys (FIDO2) for your organization: Restrict specific keys](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-enable-passkey-fido2#passkey-optional-settings)

### Details of configuration item
| | |
|-|-|
| **Recommendation** | You should use Block or Allow as value to allow- or blocklisting of AAGuids. |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2') |
| **Setting** | `keyRestrictions.aaGuids -notcontains $null -and ($result.keyRestrictions.enforcementType -eq 'allow' -or $result.keyRestrictions.enforcementType -eq 'block')` |
| **Recommended Value** | 'true' |
| **Default Value** | false |
| **Graph API Docs** | [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/fido2authenticationmethodconfiguration) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



