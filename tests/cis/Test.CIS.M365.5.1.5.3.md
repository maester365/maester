The default app management policy blocks the addition of new client secrets to applications and service principals.

Client secrets are long-lived passwords that are often stored in source code, pipelines and chat. Anyone who finds one can sign in as the application and use its permissions. Certificates and federated credentials, such as managed identities or workload identity federation, are harder to leak and easier to rotate.

The restriction only affects credentials added after it takes effect, and existing apps keep working until they need a new secret. Create exemption policies for the apps that cannot move yet, instead of leaving the default open.

#### Remediation action

1. Connect to Microsoft Graph with an account that has the Global Administrator role, or with the Security Administrator and Application Administrator roles.
2. Retrieve the current default app management policy before sending an update. In each of `applicationRestrictions` and `servicePrincipalRestrictions`, find the `passwordCredentials` entry whose `restrictionType` is `passwordAddition`. Modify that entry in place when it exists; add one only when no matching entry exists. Preserve every other `passwordCredentials` entry in both collections in the update. Sending only the target restriction can disable other active restrictions.
3. Set `isEnabled` to `true`. For each matching `passwordAddition` entry, set `state` to `enabled` and keep its existing `restrictForAppsCreatedAfterDateTime` if it is earlier than the oldest object in that collection. Otherwise, set it to a date before the oldest application or service principal in that collection. Use the same enabled state and an appropriate cutoff date for any new entry. Objects created before their collection's cutoff date are exempt.
4. Check that your applications use certificates or managed identities before enforcing.

#### Related links

* [Microsoft Entra admin center - Application policies](https://aka.ms/app-mgmt-policy-ux)
* [Enforce app management policies in Microsoft Entra ID](https://learn.microsoft.com/graph/api/resources/appmanagementpolicy)
* [Update tenantAppManagementPolicy](https://learn.microsoft.com/graph/api/tenantappmanagementpolicy-update)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.5.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
