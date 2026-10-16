The default app management policy limits how long a certificate credential can be valid, to 180 days or less.

A certificate that is valid for years gives a stolen private key a long useful life. A shorter maximum lifetime forces replacement and limits the window in which a copied key can be used.

The restriction applies to certificates that are added after it takes effect. Automate certificate renewal before enforcing, because an expired certificate breaks the application that uses it.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Create or update the default app management policy with the Microsoft Graph API or Microsoft Graph PowerShell, as described in the Microsoft Learn articles below.
3. Set `isEnabled` to `true` and, under both `applicationRestrictions` and `servicePrincipalRestrictions`, add a `keyCredentials` restriction of type `asymmetricKeyLifetime` with `maxLifetime` set to `P180D` or shorter, `state` set to `enabled` and `restrictForAppsCreatedAfterDateTime` set to a date in the past or today.

#### Related links

* [Microsoft Entra admin center - App registrations](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade/quickStartType~/null/sourceType/Microsoft_AAD_IAM)
* [Enforce app management policies in Microsoft Entra ID](https://learn.microsoft.com/graph/api/resources/appmanagementpolicy)
* [Update tenantAppManagementPolicy](https://learn.microsoft.com/graph/api/tenantappmanagementpolicy-update)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.5.6](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
