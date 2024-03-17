---
title: Authentication binding - Protected Level (authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode)
slug: /tests/EIDSCA.authenticationMethodsPolicy.authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode
---

# Authentication binding - Protected Level

Select the default protection level for all certificate bindings. The default binding will ensure the certificates bind to the selected protection strength setting unless special rules are applied. To override the default, create special rules.

| | |
|-|-|
| **Name** | authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode |
| **Control** | Authentication Method - Certificate-based authentication |
| **Description** | Define configuration settings and users or groups that are enabled to use certificate-based authentication. |
| **Severity** | Medium |

## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate') |
| **Setting** | `authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode` |
| **Recommended Value** | '' |
| **Default Value** | x509CertificateSingleFactor |
| **Graph API Docs** | [certificateBasedAuthConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/certificatebasedauthconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



