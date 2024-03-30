---
title: EIDSCA.PR05 - Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds
slug: /tests/EIDSCA.PR05
sidebar_class_name: hidden
---

# Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds

The minimum length in seconds of each lockout. If an account locks repeatedly, this duration increases.

| | |
|-|-|
| **Name** | LockoutDurationInSeconds |
| **Control** | Default Settings - Password Rule Settings |
| **Description** | Define the password protection and Smart Lockout configurations that can be used to customize the tenant-wide and object-specific restrictions and allowed behavior |
| **Severity** | High |

## How to fix
| | |
|-|-|
| **Recommendation** | [Prevent attacks using smart lockout - Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/en-us/azure/active-directory/authentication/howto-password-smart-lockout) |
| **Configuration** | settings |
| **Setting** | `values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value` |
| **Recommended Value** | '60' |
| **Default Value** | 60 |
| **Graph API Docs** | [directorySetting resource type - Microsoft Graph beta - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |
| **Azure Portal** | [View in Azure Portal](https://portal.azure.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection) | 


