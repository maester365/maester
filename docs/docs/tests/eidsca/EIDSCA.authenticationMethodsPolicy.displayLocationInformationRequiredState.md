---
title: Show geographic location in push and passwordless notifications (displayLocationInformationRequiredState)
slug: /tests/EIDSCA.authenticationMethodsPolicy.displayLocationInformationRequiredState
sidebar_class_name: hidden
---

# Show geographic location in push and passwordless notifications

Determines whether the user's Authenticator app will show them the geographic location of where the authentication request originated from.

| | |
|-|-|
| **Name** | displayLocationInformationRequiredState |
| **Control** | Authentication Method - Microsoft Authenticator |
| **Description** | Define configuration settings and users or groups that are enabled to use Authenticator App |
| **Severity** | High |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator') |
| **Setting** | `featureSettings.displayLocationInformationRequiredState.state` |
| **Recommended Value** | 'enabled' |
| **Default Value** | enabled |
| **Graph API Docs** | [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



