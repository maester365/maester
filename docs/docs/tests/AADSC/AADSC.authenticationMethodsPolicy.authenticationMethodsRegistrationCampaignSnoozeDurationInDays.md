---
title: AADSC.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignSnoozeDurationInDays
description: authenticationMethodsRegistrationCampaignSnoozeDurationInDays - Registration campaign - Days allowed to snooze
---

# Registration campaign - Days allowed to snooze

Specifies the number of days that the user sees a prompt again if they select 'Not now' and snoozes the prompt. Minimum: 0 days. Maximum: 14 days.

| | |
|-|-|
| **Name** | authenticationMethodsRegistrationCampaignSnoozeDurationInDays |
| **Control** | Authentication Method - General Settings |
| **Description** | The tenant-wide policy that controls which authentication methods are allowed in the tenant, authentication method registration requirements, and self-service password reset settings. |
| **Severity** | Informational |



## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy |
| **Setting** | `registrationEnforcement.authenticationMethodsRegistrationCampaign.snoozeDurationInDays` |
| **Recommended Value** | '' |
| **Default Value** |  |
| **Graph API Docs** | [Get authenticationMethodsPolicy - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/authenticationmethodspolicy-get) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |


