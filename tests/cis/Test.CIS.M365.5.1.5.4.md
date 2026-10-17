The default app management policy limits how long a client secret can be valid, to 180 days or less.

A client secret that never expires stays useful to an attacker for as long as nobody notices that it leaked. A short maximum lifetime forces rotation, which limits the window in which a leaked secret can be used and removes forgotten secrets.

The restriction applies to new secrets and to secrets that are added after the date set in the restriction. Make sure rotation is automated or monitored before enforcing, because a secret that expires unexpectedly breaks the application that uses it.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Create or update the default app management policy with the Microsoft Graph API or Microsoft Graph PowerShell, as described in the Microsoft Learn articles below.
3. Set `isEnabled` to `true` and, under both `applicationRestrictions` and `servicePrincipalRestrictions`, add a `passwordCredentials` restriction of type `passwordLifetime` with `maxLifetime` set to `P180D` or shorter, `state` set to `enabled` and `restrictForAppsCreatedAfterDateTime` set to a date before the oldest application in the tenant, such as the date the tenant was created. Applications created before that date are exempt, so a later date leaves existing applications out.

#### Related links

* [Microsoft Entra admin center - App registrations](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade/quickStartType~/null/sourceType/Microsoft_AAD_IAM)
* [Enforce app management policies in Microsoft Entra ID](https://learn.microsoft.com/graph/api/resources/appmanagementpolicy)
* [Update tenantAppManagementPolicy](https://learn.microsoft.com/graph/api/tenantappmanagementpolicy-update)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.5.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
