The default app management policy limits how long a client secret can be valid, to 180 days or less.

A client secret that never expires stays useful to an attacker for as long as nobody notices that it leaked. A short maximum lifetime forces rotation, which limits the window in which a leaked secret can be used and removes forgotten secrets. The same limit also caps how long a secret that an attacker adds to an application stays usable.

The restriction applies to new secrets added after it takes effect, on applications and service principals created after the date set in the restriction. Make sure rotation is automated or monitored before enforcing, because a secret that expires unexpectedly breaks the application that uses it.

#### Remediation action

1. Connect to Microsoft Graph with an account that has the Global Administrator role, or with the Security Administrator and Application Administrator roles.
2. Retrieve the current default app management policy before sending an update. In each of `applicationRestrictions` and `servicePrincipalRestrictions`, find the `passwordCredentials` entry whose `restrictionType` is `passwordLifetime`. Modify that entry in place when it exists; add one only when no matching entry exists. Preserve every other `passwordCredentials` entry in both collections in the update. Sending only the target restriction can disable other active restrictions.
3. Set `isEnabled` to `true`. For each matching `passwordLifetime` entry, set `maxLifetime` to `P180D` or shorter and `state` to `enabled`, and keep its existing `restrictForAppsCreatedAfterDateTime` only if it is earlier than the oldest object in that collection; otherwise, use a date before that oldest object. When choosing the oldest service principal, treat a null `createdDateTime` as January 1, 2019, as Microsoft Graph does. Apply the same cutoff rule to a new entry. If a collection is empty, use the tenant creation date or an earlier date as its cutoff. Objects created before their collection's cutoff date are exempt.

#### Related links

* [Microsoft Entra admin center - Application policies](https://aka.ms/app-mgmt-policy-ux)
* [Enforce app management policies in Microsoft Entra ID](https://learn.microsoft.com/graph/api/resources/appmanagementpolicy)
* [Update tenantAppManagementPolicy](https://learn.microsoft.com/graph/api/tenantappmanagementpolicy-update)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.5.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
