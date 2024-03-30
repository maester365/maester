---
title: EIDSCA.CR01 - Consent Framework - Admin Consent Request - Users can request admin consent to apps they are unable to consent to
slug: /tests/EIDSCA.CR01
sidebar_class_name: hidden
---

# Consent Framework - Admin Consent Request - Users can request admin consent to apps they are unable to consent to

Defines if admin consent request feature is enabled or disabled

| | |
|-|-|
| **Name** | isEnabled |
| **Control** | Consent Framework - Admin Consent Request |
| **Description** | Represents the policy for enabling or disabling the Azure AD admin consent workflow. The admin consent workflow allows users to request access for apps that they wish to use and that require admin authorization before users can use the apps to access organizational data.  |
| **Severity** |  |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/adminConsentRequestPolicy |
| **Setting** | `isEnabled` |
| **Recommended Value** | 'true' |
| **Default Value** | false |
| **Graph API Docs** | [adminConsentRequestPolicy resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/adminconsentrequestpolicy) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/adminConsentRequestPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |
| **Azure Portal** | [View in Azure Portal](https://portal.azure.com/#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/AdminConsentSettings) | 


