The default app management policy blocks the addition of new client secrets to applications and service principals.

Client secrets are long-lived passwords that are often stored in source code, pipelines and chat. Anyone who finds one can sign in as the application and use its permissions. Certificates and federated credentials, such as managed identities or workload identity federation, are harder to leak and easier to rotate.

The restriction only affects credentials added after it takes effect, and existing apps keep working until they need a new secret. Create exemption policies for the apps that cannot move yet, instead of leaving the default open.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Create or update the default app management policy with the Microsoft Graph API or Microsoft Graph PowerShell, as described in the Microsoft Learn articles below.
3. Set `isEnabled` to `true` and, under both `applicationRestrictions` and `servicePrincipalRestrictions`, add a `passwordCredentials` restriction of type `passwordAddition` with `state` set to `enabled` and `restrictForAppsCreatedAfterDateTime` set to a date before the oldest application in the tenant, such as the date the tenant was created. Applications created before that date are exempt, so a later date leaves existing applications out.
4. Check that your applications use certificates or managed identities before enforcing.

#### Related links

* [Microsoft Entra admin center - App registrations](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade/quickStartType~/null/sourceType/Microsoft_AAD_IAM)
* [Enforce app management policies in Microsoft Entra ID](https://learn.microsoft.com/graph/api/resources/appmanagementpolicy)
* [Update tenantAppManagementPolicy](https://learn.microsoft.com/graph/api/tenantappmanagementpolicy-update)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.5.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
