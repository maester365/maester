---
title: Excluded users/groups to show geographic location in push and passwordless notifications (displayLocationInformationRequiredExcluded)
slug: /tests/EIDSCA.authenticationMethodsPolicy.displayLocationInformationRequiredExcluded
sidebar_class_name: hidden
---

# Excluded users/groups to show geographic location in push and passwordless notifications

Object Id or scope of users which are excluded from showing geographic location in the Authenticator App.

| | |
|-|-|
| **Name** | displayLocationInformationRequiredExcluded |
| **Control** | Authentication Method - Microsoft Authenticator |
| **Description** | Define configuration settings and users or groups that are enabled to use Authenticator App |
| **Severity** | Medium |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator') |
| **Setting** | `featureSettings.displayLocationInformationRequiredState.excludeTarget.id` |
| **Recommended Value** | '' |
| **Default Value** |  |
| **Graph API Docs** | [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



