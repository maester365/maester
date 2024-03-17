---
title: Registration campaign - Included users/groups (authenticationMethodsRegistrationCampaignIncluded)
slug: /tests/EIDSCA.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignIncluded
sidebar_class_name: hidden
---

# Registration campaign - Included users/groups

Users and groups of users that are prompted to set up the authentication method.

| | |
|-|-|
| **Name** | authenticationMethodsRegistrationCampaignIncluded |
| **Control** | Authentication Method - General Settings |
| **Description** | The tenant-wide policy that controls which authentication methods are allowed in the tenant, authentication method registration requirements, and self-service password reset settings. |
| **Severity** | Informational |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy |
| **Setting** | `registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.id` |
| **Recommended Value** | '' |
| **Default Value** | all_users |
| **Graph API Docs** | [Get authenticationMethodsPolicy - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/authenticationmethodspolicy-get) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



