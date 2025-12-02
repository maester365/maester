---
title: EIDSCA.AM04 - Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications
slug: /tests/EIDSCA.AM04
sidebar_class_name: hidden
---

# Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications

Object Id or scope of users which will be showing number matching in the Authenticator App.

| | |
|-|-|
| **Name** | numberMatchingRequiredStateIncluded |
| **Control** | Authentication Method - Microsoft Authenticator |
| **Description** | Define configuration settings and users or groups that are enabled to use Authenticator App |
| **Severity** | High |

## How to fix



### Details of configuration item
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator') |
| **Setting** | `featureSettings.numberMatchingRequiredState.includeTarget.id` |
| **Recommended Value** | 'all_users' |
| **Default Value** | all_users |
| **Graph API Docs** | [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



