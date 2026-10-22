5.1.5.5 (L1) Ensure new application passwords are system-generated

In Microsoft Entra ID, applications and service principals can authenticate using password credentials (also referred to as client secrets). By default, when adding a new password credential, the caller may supply a custom password value or allow the system to generate one. This setting enforces a tenant-wide restriction that blocks the use of custom password values, requiring all new password credentials to be system-generated. The policy is implemented through the default app management policy and applies to all applications unless scoped exceptions are configured.

The setting does not affect existing password credentials; credentials created before the policy was enabled remain valid until they expire or are explicitly removed.

The recommended state is **Block custom passwords** set to **On**.

#### Rationale

Custom password values are chosen by the caller and are susceptible to low entropy, predictable patterns, and reuse across multiple applications. A weak or reused client secret that is compromised through source code exposure, logging, or a supply-chain breach can be trivially exploited by an attacker to authenticate as the application. System-generated passwords use random values of sufficient length and complexity, making them resistant to brute-force and dictionary attacks. Blocking custom passwords removes the weakest credential creation path and ensures that all new client secrets meet a consistent entropy baseline.

#### Impact

Any automated process, pipeline, or script that programmatically creates a client secret by supplying a custom password value will be blocked once the policy is enabled, unless an exception is configured. Most tooling, including the Microsoft Entra admin center, Azure CLI, and Azure PowerShell, already defaults to system-generated values, so the operational impact for typical workflows is minimal. Organizations that rely on custom password values in their automation will need to update those workflows to omit the custom value and accept the system-generated secret.

Organizations that have policies or regulatory requirements that mandate specific password formats may need to maintain exclusions for certain applications. Exceptions should be scoped narrowly and reviewed regularly to minimize risk.

#### Remediation action

To remediate using the UI:

1. Navigate to [Microsoft Entra admin center](https://entra.microsoft.com).
2. Expand **Entra ID** and select **Enterprise apps**.
3. Under **Security** select [**Application policies**](https://aka.ms/app-mgmt-policy-ux).
4. Select **Block custom passwords**.
5. Set **Status** to **On**.
6. Set **Applies to** to one of the following:
    * **All applications**
    * **All applications with exclusions** (if using exclusions, ensure they are reviewed annually).
7. Set **Only apply to apps created after** to a desired date or leave it unconfigured.
8. Select **Save and close** to apply the changes.

To remediate using the Microsoft Graph API:

> **Important:** The PATCH request replaces the `passwordCredentials` array in full. Retrieve the current policy first and include all existing entries in the request body to avoid overwriting other configured restrictions or exclusions.

1. Execute a **GET** request to retrieve the current policy: `v1.0/policies/defaultAppManagementPolicy`
2. Modify the returned JSON to reflect the following changes:
   * Set `isEnabled` to `true`.
   * Under `applicationRestrictions.passwordCredentials`, locate the entry where `restrictionType` is `customPasswordAddition` and set the following:
      * `state` to `enabled`
      * `restrictForAppsCreatedAfterDateTime` to `0001-01-01T00:00:00Z` or a desired date.
   * Under `servicePrincipalRestrictions.passwordCredentials`, locate the entry where `restrictionType` is `customPasswordAddition` and set the following:
      * `state` to `enabled`
      * `restrictForAppsCreatedAfterDateTime` to `0001-01-01T00:00:00Z` or a desired date.
3. Execute a **PATCH** request to the same URI with the modified JSON in the request body to apply the changes.

> **Note:** Maester also checks that the restriction covers every existing application and service principal. Objects created before the **Only apply to apps created after** date (`restrictForAppsCreatedAfterDateTime`) are exempt from the restriction, so the check fails while any exist. Leave the date unconfigured or set it to `0001-01-01T00:00:00Z`, or to a date before your oldest application and service principal.

#### Related links

* [Microsoft Entra admin center - Application policies](https://aka.ms/app-mgmt-policy-ux)
* [Enforce app management policies in Microsoft Entra ID](https://learn.microsoft.com/graph/api/resources/appmanagementpolicy)
* [Update tenantAppManagementPolicy](https://learn.microsoft.com/graph/api/tenantappmanagementpolicy-update)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.5.5](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
