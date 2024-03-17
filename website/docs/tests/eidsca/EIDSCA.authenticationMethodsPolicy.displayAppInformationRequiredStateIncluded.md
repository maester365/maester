---
title: Included users/groups to show application name in push and passwordless notifications (displayAppInformationRequiredStateIncluded)
slug: /tests/EIDSCA.authenticationMethodsPolicy.displayAppInformationRequiredStateIncluded
sidebar_class_name: hidden
---

# Included users/groups to show application name in push and passwordless notifications

Object Id or scope of users which will be showing app information in the Authenticator App.

| | |
|-|-|
| **Name** | displayAppInformationRequiredStateIncluded |
| **Control** | Authentication Method - Microsoft Authenticator |
| **Description** | Define configuration settings and users or groups that are enabled to use Authenticator App |
| **Severity** | High |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator') |
| **Setting** | `featureSettings.displayAppInformationRequiredState.includeTarget.id` |
| **Recommended Value** | 'all_users' |
| **Default Value** | all_users |
| **Graph API Docs** | [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



