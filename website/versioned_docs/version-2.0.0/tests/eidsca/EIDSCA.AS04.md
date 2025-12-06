---
title: EIDSCA.AS04 - Authentication Method - SMS - Use for sign-in
slug: /tests/EIDSCA.AS04
sidebar_class_name: hidden
---

# Authentication Method - SMS - Use for sign-in

Determines if users can use this authentication method to sign in to Microsoft Entra ID. true if users can use this method for primary authentication, otherwise false.

| | |
|-|-|
| **Name** | isUsableForSignIn |
| **Control** | Authentication Method - SMS |
| **Description** | Define configuration settings and users or groups that are enabled to use text messages for authentication. |
| **Severity** | High |

## How to fix

[Microsoft Learn - Configure and enable users for SMS-based authentication using Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/authentication/howto-authentication-sms-signin)

### Details of configuration item
| | |
|-|-|
| **Recommendation** | Avoid to use SMS as primary sign in factor (instead of a password) and consider to implement a MFA or passwordless option also for your special user groups, such as front-line workers. |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms') |
| **Setting** | `includeTargets.isUsableForSignIn` |
| **Recommended Value** | 'false' |
| **Default Value** | true |
| **Graph API Docs** | [phoneAuthenticationMethod resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/phoneauthenticationmethod) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



