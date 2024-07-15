---
title: EIDSCA.AG01 - Authentication Method - General Settings - Manage migration
slug: /tests/EIDSCA.AG01
sidebar_class_name: hidden
---

# Authentication Method - General Settings - Manage migration

The state of migration of the authentication methods policy from the legacy multifactor authentication and self-service password reset (SSPR) policies. In January 2024, the legacy multifactor authentication and self-service password reset policies will be deprecated and you'll manage all authentication methods here in the authentication methods policy. Use this control to manage your migration from the legacy policies to the new unified policy.

| | |
|-|-|
| **Name** | policyMigrationState |
| **Control** | Authentication Method - General Settings |
| **Description** | The tenant-wide policy that controls which authentication methods are allowed in the tenant, authentication method registration requirements, and self-service password reset settings. |
| **Severity** | Informational |

## How to fix

[Microsoft Learn - How to manage authentication methodes](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-authentication-methods-manage#start-the-migration)

### Details of configuration item
| | |
|-|-|
| **Recommendation** | On September 30th, 2025, the legacy multifactor authentication and self-service password reset policies will be deprecated and you'll manage all authentication methods here in the authentication methods policy. Use this control to manage your migration from the legacy policies to the new unified policy. |
| **Configuration** | policies/authenticationMethodsPolicy |
| **Setting** | `policyMigrationState` |
| **Recommended Value** | 'migrationComplete' |
| **Default Value** | premigration |
| **Graph API Docs** | [Get authenticationMethodsPolicy - Microsoft Graph v1.0 - Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/authenticationmethodspolicy-get) |
| **Graph Explorer** | [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com) |



