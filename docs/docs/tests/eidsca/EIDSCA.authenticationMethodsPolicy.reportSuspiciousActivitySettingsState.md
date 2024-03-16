---
title: EIDSCA.authenticationMethodsPolicy.reportSuspiciousActivitySettingsState
description: reportSuspiciousActivitySettingsState - Report suspicious activity - State
slug: /tests/EIDSCA.authenticationMethodsPolicy.reportSuspiciousActivitySettingsState
---

# Report suspicious activity - State

Allows users to report suspicious activities if they receive an authentication request that they did not initiate. This control is available when using the Microsoft Authenticator app and voice calls. Reporting suspicious activity will set the user's risk to high. If the user is subject to risk-based Conditional Access policies, they may be blocked.

| | |
|-|-|
| **Name** | reportSuspiciousActivitySettingsState |
| **Control** | Authentication Method - General Settings |
| **Description** | The tenant-wide policy that controls which authentication methods are allowed in the tenant, authentication method registration requirements, and self-service password reset settings. |
| **Severity** | Medium |

## How to fix
| | |
|-|-|
| **Recommendation** | Allows to integrate report of fraud attempt by users to identity protection: Users who report an MFA prompt as suspicious are set to High User Risk. Administrators can use risk-based policies to limit access for these users, or enable self-service password reset (SSPR) for users to remediate problems on their own. |
| **Configuration** | policies/authenticationMethodsPolicy |
| **Setting** | `reportSuspiciousActivitySettings.state` |
| **Recommended Value** | 'enabled' |
| **Default Value** | default |
| **Graph API Docs** | [Get authenticationMethodsPolicy - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/authenticationmethodspolicy-get) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |
| **Azure Portal** | [View in Azure Portal](https://portal.azure.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods) | 


