---
title: EIDSCA.AF01 - Authentication Method - FIDO2 security key - State
slug: /tests/EIDSCA.AF01
sidebar_class_name: hidden
---

# Authentication Method - FIDO2 security key - State

Whether the FIDO2 security keys is enabled in the tenant.

| | |
|-|-|
| **Name** | state |
| **Control** | Authentication Method - FIDO2 security key |
| **Description** | Define configuration settings and users or groups that are enabled to use FIDO2 security keys |
| **Severity** | High |

## How to fix

[Microsoft Learn - Enable passkeys (FIDO2) for your organization: Enable FIDO2 security key](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-enable-passkey-fido2#enable-passkey-authentication-method)

### Details of configuration item
| | |
|-|-|
| **Recommendation** | enabled |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2') |
| **Setting** | `state` |
| **Recommended Value** | 'enabled' |
| **Default Value** | enabled |
| **Graph API Docs** | [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/fido2authenticationmethodconfiguration) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



