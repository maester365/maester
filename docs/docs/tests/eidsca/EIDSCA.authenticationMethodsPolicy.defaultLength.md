---
title: Length (defaultLength)
slug: /tests/EIDSCA.authenticationMethodsPolicy.defaultLength
sidebar_class_name: hidden
---

# Length

Default length in characters of a Temporary Access Pass object. Must be between 8 and 48 characters.

| | |
|-|-|
| **Name** | defaultLength |
| **Control** | Authentication Method - Temporary Access Pass |
| **Description** | Define configuration settings and users or groups that are enabled to use Temporary Access Pass |
| **Severity** | High |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass') |
| **Setting** | `defaultLength` |
| **Recommended Value** | '' |
| **Default Value** | 8 |
| **Graph API Docs** | [temporaryAccessPassAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/temporaryaccesspassauthenticationmethodconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



