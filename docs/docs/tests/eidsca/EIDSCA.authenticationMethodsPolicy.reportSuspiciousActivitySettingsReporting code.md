---
title: Report suspicious activity - Reporting code (reportSuspiciousActivitySettingsReporting code)
slug: /tests/EIDSCA.authenticationMethodsPolicy.reportSuspiciousActivitySettingsReporting code
---

# Report suspicious activity - Reporting code

Reporting code must be 0 - 9.

| | |
|-|-|
| **Name** | reportSuspiciousActivitySettingsReporting code |
| **Control** | Authentication Method - General Settings |
| **Description** | The tenant-wide policy that controls which authentication methods are allowed in the tenant, authentication method registration requirements, and self-service password reset settings. |
| **Severity** | Informational |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy |
| **Setting** | `reportSuspiciousActivitySettings.voiceReportingCode` |
| **Recommended Value** | '' |
| **Default Value** |  |
| **Graph API Docs** | [Get authenticationMethodsPolicy - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/authenticationmethodspolicy-get) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |
| **Azure Portal** | [View in Azure Portal](https://portal.azure.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods) | 


