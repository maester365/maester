---
title: EIDSCA.AM01 - Authentication Method - Microsoft Authenticator - State
slug: /tests/EIDSCA.AM01
sidebar_class_name: hidden
---

# Authentication Method - Microsoft Authenticator - State

Whether the Authenticator App is enabled in the tenant.

| | |
|-|-|
| **Name** | state |
| **Control** | Authentication Method - Microsoft Authenticator |
| **Description** | Define configuration settings and users or groups that are enabled to use Authenticator App |
| **Severity** | High |

## How to fix

[Microsoft Learn - Enable Authenticator App](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-authentication-methods-manage#authentication-methods-policy)

### Details of configuration item
| | |
|-|-|
| **Recommendation** | enabled |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator') |
| **Setting** | `state` |
| **Recommended Value** | 'enabled' |
| **Default Value** | enabled |
| **Graph API Docs** | [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



