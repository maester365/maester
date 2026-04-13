---
title: EIDSCA.AT02 - Authentication Method - Temporary Access Pass - One-time
slug: /tests/EIDSCA.AT02
sidebar_class_name: hidden
---

# Authentication Method - Temporary Access Pass - One-time

Determines whether the pass is limited to a one-time use.

| | |
|-|-|
| **Name** | isUsableOnce |
| **Control** | Authentication Method - Temporary Access Pass |
| **Description** | Define configuration settings and users or groups that are enabled to use Temporary Access Pass |
| **Severity** | Medium |

## How to fix

[Microsoft Learn - Require one-time use (Step 5)](https://learn.microsoft.com/en-us/entra/identity/authentication/howto-authentication-temporary-access-pass#enable-the-temporary-access-pass-policy)

### Details of configuration item
| | |
|-|-|
| **Recommendation** | Avoid to allow reusable passes and restrict usage to one-time use (if applicable) |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass') |
| **Setting** | `isUsableOnce` |
| **Recommended Value** | 'true' |
| **Default Value** | false |
| **Graph API Docs** | [temporaryAccessPassAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/temporaryaccesspassauthenticationmethodconfiguration) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



