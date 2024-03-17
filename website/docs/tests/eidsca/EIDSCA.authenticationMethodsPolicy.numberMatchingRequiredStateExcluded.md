---
title: Excluded users/groups of number matching for push notifications (numberMatchingRequiredStateExcluded)
slug: /tests/EIDSCA.authenticationMethodsPolicy.numberMatchingRequiredStateExcluded
sidebar_class_name: hidden
---

# Excluded users/groups of number matching for push notifications

Object Id or scope of users which be able excluded from showing number matching in the Authenticator App.

| | |
|-|-|
| **Name** | numberMatchingRequiredStateExcluded |
| **Control** | Authentication Method - Microsoft Authenticator |
| **Description** | Define configuration settings and users or groups that are enabled to use Authenticator App |
| **Severity** | High |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator') |
| **Setting** | `featureSettings.numberMatchingRequiredState.excludeTarget.id` |
| **Recommended Value** | '' |
| **Default Value** |  |
| **Graph API Docs** | [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



