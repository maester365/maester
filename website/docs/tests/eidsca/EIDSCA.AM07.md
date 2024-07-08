---
title: EIDSCA.AM07 - Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications
slug: /tests/EIDSCA.AM07
sidebar_class_name: hidden
---

# Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications

Object Id or scope of users which will be showing app information in the Authenticator App.

| | |
|-|-|
| **Name** | displayAppInformationRequiredStateIncluded |
| **Control** | Authentication Method - Microsoft Authenticator |
| **Description** | Define configuration settings and users or groups that are enabled to use Authenticator App |
| **Severity** | High |

## How to fix



### Details of configuration item
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator') |
| **Setting** | `featureSettings.displayAppInformationRequiredState.includeTarget.id` |
| **Recommended Value** | 'all_users' |
| **Default Value** | all_users |
| **Graph API Docs** | [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



