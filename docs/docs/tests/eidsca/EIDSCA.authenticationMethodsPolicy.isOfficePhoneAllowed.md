---
title: Phone Options - Office (isOfficePhoneAllowed)
slug: /tests/EIDSCA.authenticationMethodsPolicy.isOfficePhoneAllowed
---

# Phone Options - Office

Determines whether voice call is usable on office phone numbers. Mobile phone calls are always allowed.

| | |
|-|-|
| **Name** | isOfficePhoneAllowed |
| **Control** | Authentication Method - Voice call |
| **Description** | Define configuration settings and users or groups that are enabled to use voice call for authentication. Voice call is not usable as a first-factor authentication method. |
| **Severity** | High |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice') |
| **Setting** | `isOfficePhoneAllowed` |
| **Recommended Value** | '' |
| **Default Value** | disabled |
| **Graph API Docs** |  |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



