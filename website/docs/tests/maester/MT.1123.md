---
title: MT.1123 - Legacy per-user MFA should be migrated to authentication methods policy
description: Checks if the tenant has completed the migration from legacy per-user MFA to the authentication methods policy.
slug: /tests/MT.1123
sidebar_class_name: hidden
---

# Legacy per-user MFA should be migrated to authentication methods policy

## Description

The legacy per-user MFA and self-service password reset (SSPR) policies are deprecated. On September 30, 2025, the legacy multifactor authentication and self-service password reset policies will be fully retired. All authentication methods should be managed through the unified authentication methods policy to reduce administrative complexity and potential security misconfigurations.

This test checks the `policyMigrationState` property of the authentication methods policy. A value of `migrationComplete` (or empty for new tenants that never had legacy settings) indicates that the migration has been completed.

## How to fix

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least an Authentication Policy Administrator.
2. Browse to **Protection** > **Authentication methods** > **[Policies](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)**.
3. Follow the process of [migrating from the legacy MFA and SSPR policies to the unified authentication methods policy](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-authentication-methods-manage).
4. Once ready to finish the migration, [set the **Manage Migration** option to **Migration Complete**](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-authentication-methods-manage#finish-the-migration).

## Learn more

- [Entra admin center - Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)
- [How to migrate MFA and SSPR policy settings to the authentication methods policy](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-authentication-methods-manage)
- [Get authenticationMethodsPolicy - Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/authenticationmethodspolicy-get)
