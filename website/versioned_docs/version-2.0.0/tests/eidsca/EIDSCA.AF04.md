---
title: EIDSCA.AF04 - Authentication Method - FIDO2 security key - Enforce key restrictions
slug: /tests/EIDSCA.AF04
sidebar_class_name: hidden
---

# Authentication Method - FIDO2 security key - Enforce key restrictions

Manages if registration of FIDO2 keys should be restricted.

| | |
|-|-|
| **Name** | keyRestrictions.isEnforced |
| **Control** | Authentication Method - FIDO2 security key |
| **Description** | Define configuration settings and users or groups that are enabled to use FIDO2 security keys |
| **Severity** | Low |

## How to fix

[Microsoft Learn - Enable passkeys (FIDO2) for your organization: Enforce key restrictions](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-enable-passkey-fido2#passkey-optional-settings)

### Details of configuration item
| | |
|-|-|
| **Recommendation** | Restrict usage of FIDO2 from unauthorized vendors or platforms |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2') |
| **Setting** | `keyRestrictions.isEnforced` |
| **Recommended Value** | 'true' |
| **Default Value** | false |
| **Graph API Docs** | [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/fido2authenticationmethodconfiguration) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



