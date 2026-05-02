---
title: EIDSCA.AM06 - Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications
slug: /tests/EIDSCA.AM06
sidebar_class_name: hidden
---

# Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications

Determines whether the user's Authenticator app will show them the client app they are signing into.

| | |
|-|-|
| **Name** | displayAppInformationRequiredState |
| **Control** | Authentication Method - Microsoft Authenticator |
| **Description** | Define configuration settings and users or groups that are enabled to use Authenticator App |
| **Severity** | High |

## How to fix



### Details of configuration item
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator') |
| **Setting** | `featureSettings.displayAppInformationRequiredState.state` |
| **Recommended Value** | 'enabled' |
| **Default Value** | enabled |
| **Graph API Docs** | [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



