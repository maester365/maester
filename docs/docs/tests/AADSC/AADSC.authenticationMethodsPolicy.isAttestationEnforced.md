---
title: AADSC.authenticationMethodsPolicy.isAttestationEnforced
description: isAttestationEnforced - Enforce attestation
---

# Enforce attestation

Requires the FIDO security key metadata to be published and verified with the FIDO Alliance Metadata Service, and also pass Microsoft???s additional set of validation testing.

| | |
|-|-|
| **Name** | isAttestationEnforced |
| **Control** | Authentication Method - FIDO2 security key |
| **Description** | Define configuration settings and users or groups that are enabled to use FIDO2 security keys |
| **Severity** | High |



## How to fix
| | |
|-|-|
| **Recommendation** |  |
| **Configuration** | policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2') |
| **Setting** | `isAttestationEnforced` |
| **Recommended Value** | 'true' |
| **Default Value** | true |
| **Graph API Docs** | [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/fido2authenticationmethodconfiguration) |
| **Graph Explorer** | [View in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |


