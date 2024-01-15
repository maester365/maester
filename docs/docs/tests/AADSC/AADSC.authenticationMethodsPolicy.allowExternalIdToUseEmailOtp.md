---
title: AADSC.authenticationMethodsPolicy.allowExternalIdToUseEmailOtp
description: allowExternalIdToUseEmailOtp - Allow external users to use email OTP
---

# Allow external users to use email OTP

Determines whether email one-time password is usable by external users for authentication. Tenants in the default state who did not use public preview will automatically have email OTP enabled beginning in March 2021.

| | |
|-|-|
| **Name** | allowExternalIdToUseEmailOtp |
| **Control** | Authentication Method - Email OTP |
| **Description** | Define configuration settings and users or groups that are enabled to use email address registered to a user. For members of a tenant, email OTP is usable only for Self-Service Password Recovery. It may also be configured to be used for sign-in by guest users. |
| **Severity** | High |



## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email') |
| **Setting** | `allowExternalIdToUseEmailOtp` |
| **Recommended Value** | '' |
| **Default Value** | default |
| **Graph API Docs** | [emailAuthenticationMethod resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/emailauthenticationmethod) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |


