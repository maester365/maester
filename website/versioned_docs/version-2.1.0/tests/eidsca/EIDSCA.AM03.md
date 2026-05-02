---
title: EIDSCA.AM03 - Authentication Method - Microsoft Authenticator - Require number matching for push notifications
slug: /tests/EIDSCA.AM03
sidebar_class_name: hidden
---

# Authentication Method - Microsoft Authenticator - Require number matching for push notifications

Defines if number matching is required for MFA notifications.

| | |
|-|-|
| **Name** | numberMatchingRequiredState |
| **Control** | Authentication Method - Microsoft Authenticator |
| **Description** | Define configuration settings and users or groups that are enabled to use Authenticator App |
| **Severity** | High |

## How to fix



### Details of configuration item
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator') |
| **Setting** | `featureSettings.numberMatchingRequiredState.state` |
| **Recommended Value** | 'enabled' |
| **Default Value** | enabled |
| **Graph API Docs** | [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



