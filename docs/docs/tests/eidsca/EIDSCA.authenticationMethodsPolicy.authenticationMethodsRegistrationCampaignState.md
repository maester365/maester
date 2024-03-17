---
title: Registration campaign - State (authenticationMethodsRegistrationCampaignState)
slug: /tests/EIDSCA.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignState
sidebar_class_name: hidden
---

# Registration campaign - State

Configuration of a registration campaign that prompts users to set up more secure authentication methods.

| | |
|-|-|
| **Name** | authenticationMethodsRegistrationCampaignState |
| **Control** | Authentication Method - General Settings |
| **Description** | The tenant-wide policy that controls which authentication methods are allowed in the tenant, authentication method registration requirements, and self-service password reset settings. |
| **Severity** | Informational |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy |
| **Setting** | `registrationEnforcement.authenticationMethodsRegistrationCampaign.state` |
| **Recommended Value** | '' |
| **Default Value** | default |
| **Graph API Docs** | [Get authenticationMethodsPolicy - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/authenticationmethodspolicy-get) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |
| **Azure Portal** | [View in Azure Portal](https://portal.azure.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/RegistrationCampaign) | 


