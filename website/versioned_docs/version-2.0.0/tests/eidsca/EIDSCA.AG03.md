---
title: EIDSCA.AG03 - Authentication Method - General Settings - Report suspicious activity - Included users/groups
slug: /tests/EIDSCA.AG03
sidebar_class_name: hidden
---

# Authentication Method - General Settings - Report suspicious activity - Included users/groups

Object Id or scope of users which will be included to report suspicious activities if they receive an authentication request that they did not initiate.

| | |
|-|-|
| **Name** | reportSuspiciousActivitySettingsIncluded |
| **Control** | Authentication Method - General Settings |
| **Description** | The tenant-wide policy that controls which authentication methods are allowed in the tenant, authentication method registration requirements, and self-service password reset settings. |
| **Severity** | High |

## How to fix

[Microsoft Learn - Report suspicious activites](https://learn.microsoft.com/en-us/entra/identity/authentication/howto-mfa-mfasettings#report-suspicious-activity)

### Details of configuration item
| | |
|-|-|
| **Recommendation** | Apply this feature to all users. |
| **Configuration** | policies/authenticationMethodsPolicy |
| **Setting** | `reportSuspiciousActivitySettings.includeTarget.id` |
| **Recommended Value** | 'all_users' |
| **Default Value** | all_users |
| **Graph API Docs** | [Get authenticationMethodsPolicy - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/authenticationmethodspolicy-get) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



