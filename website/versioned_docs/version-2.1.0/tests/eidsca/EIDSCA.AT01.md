---
title: EIDSCA.AT01 - Authentication Method - Temporary Access Pass - State
slug: /tests/EIDSCA.AT01
sidebar_class_name: hidden
---

# Authentication Method - Temporary Access Pass - State

Whether the Temporary Access Pass is enabled in the tenant.

| | |
|-|-|
| **Name** | state |
| **Control** | Authentication Method - Temporary Access Pass |
| **Description** | Define configuration settings and users or groups that are enabled to use Temporary Access Pass |
| **Severity** | High |

## How to fix

[Microsoft Learn - Enable Temporary Access Pass](https://learn.microsoft.com/en-us/entra/identity/authentication/howto-authentication-temporary-access-pass#enable-the-temporary-access-pass-policy)

### Details of configuration item
| | |
|-|-|
| **Recommendation** | Use Temporary Access Pass for secure onboarding users (initial password replacement) and enforce MFA for registering security information in Conditional Access Policy. |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass') |
| **Setting** | `state` |
| **Recommended Value** | 'enabled' |
| **Default Value** | enabled |
| **Graph API Docs** | [temporaryAccessPassAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/temporaryaccesspassauthenticationmethodconfiguration) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



