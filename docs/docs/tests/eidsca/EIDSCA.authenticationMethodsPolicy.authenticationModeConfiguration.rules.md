---
title: Authentication binding - Rules (authenticationModeConfiguration.rules)
slug: /tests/EIDSCA.authenticationMethodsPolicy.authenticationModeConfiguration.rules
sidebar_class_name: hidden
---

# Authentication binding - Rules

Rules are configured in addition to the authentication mode to bind a specific x509CertificateRuleType to an x509CertificateAuthenticationMode.

| | |
|-|-|
| **Name** | authenticationModeConfiguration.rules |
| **Control** | Authentication Method - Certificate-based authentication |
| **Description** | Define configuration settings and users or groups that are enabled to use certificate-based authentication. |
| **Severity** |  |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate') |
| **Setting** | `authenticationModeConfiguration.rules` |
| **Recommended Value** | '' |
| **Default Value** |  |
| **Graph API Docs** | [certificateBasedAuthConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/certificatebasedauthconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



