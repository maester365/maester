Checks if the tenant has completed the migration from legacy per-user MFA to the authentication methods policy.

The legacy per-user MFA and self-service password reset (SSPR) policies are deprecated. On September 30, 2025, the legacy multifactor authentication and self-service password reset policies will be fully retired. All authentication methods should be managed through the unified authentication methods policy to reduce administrative complexity and potential security misconfigurations.

#### Remediation action:

1. In **Entra ID**, navigate to **Protection** > **[Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)**.
2. Follow the process of [migrating from the legacy MFA and SSPR policies to the unified authentication methods policy](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-authentication-methods-manage).
3. Once ready to finish the migration, [set the **Manage Migration** option to **Migration Complete**](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-authentication-methods-manage#finish-the-migration).

#### Related links

- [Entra admin center - Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)
- [How to migrate MFA and SSPR policy settings to the authentication methods policy](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-authentication-methods-manage)
- [Get authenticationMethodsPolicy - Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/authenticationmethodspolicy-get)

<!--- Results --->
%TestResult%
