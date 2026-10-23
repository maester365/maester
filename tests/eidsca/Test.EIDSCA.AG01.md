The state of migration from the legacy multifactor authentication and self-service password reset (SSPR) policies to the Authentication methods policy. Legacy policies are respected in the premigration and migrationInProgress states and ignored in the migrationComplete state.

Complete the migration from the legacy multifactor authentication and self-service password reset policies to the unified Authentication methods policy. Review the enabled methods and their user scopes before marking migration complete.

#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy
.policyMigrationState -in @('migrationComplete', '')
```

#### Remediation action

[Microsoft Learn - How to migrate to the Authentication methods policy](https://learn.microsoft.com/entra/identity/authentication/how-to-authentication-methods-manage#start-the-migration)

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/graph/graph-explorer?request=policies/authenticationMethodsPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [Get authenticationMethodsPolicy - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/graph/api/authenticationmethodspolicy-get)
- [View in Microsoft Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)



<!--- Results --->
%TestResult%
