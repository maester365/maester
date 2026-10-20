The default app management policy limits how long a certificate credential can be valid, to 180 days or less.

A certificate that is valid for years gives a stolen private key a long useful life. A shorter maximum lifetime forces replacement and limits the window in which a copied key can be used. The same limit also caps how long a certificate that an attacker adds to an application stays valid.

The restriction applies to certificates added after it takes effect, on applications and service principals created after the date set in the restriction. Automate certificate renewal before enforcing, because an expired certificate breaks the application that uses it.

#### Remediation action

1. Connect to Microsoft Graph with an account that has the Global Administrator role, or with the Security Administrator and Application Administrator roles.
2. Create or update the default app management policy with the Microsoft Graph API or Microsoft Graph PowerShell, as described in the Microsoft Learn articles below.
3. Set `isEnabled` to `true` and, under both `applicationRestrictions` and `servicePrincipalRestrictions`, add a `keyCredentials` restriction of type `asymmetricKeyLifetime` with `maxLifetime` set to `P180D` or shorter, `state` set to `enabled` and `restrictForAppsCreatedAfterDateTime` set to a date before the oldest application in the tenant, such as the date the tenant was created. Applications created before that date are exempt, so a later date leaves existing applications out.

#### Related links

* [Microsoft Entra admin center - Application policies](https://aka.ms/app-mgmt-policy-ux)
* [Enforce app management policies in Microsoft Entra ID](https://learn.microsoft.com/graph/api/resources/appmanagementpolicy)
* [Update tenantAppManagementPolicy](https://learn.microsoft.com/graph/api/tenantappmanagementpolicy-update)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.5.6](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
