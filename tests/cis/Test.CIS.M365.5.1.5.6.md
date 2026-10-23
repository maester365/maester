5.1.5.6 (L1) Ensure maximum certificate lifetime for applications does not exceed 180 days

In Microsoft Entra ID, applications and service principals can authenticate using certificate credentials. This setting enforces a tenant-wide maximum lifetime for new certificate credentials added to any application registration or service principal. When enabled, any certificate uploaded must have a validity period that falls within the configured maximum, which for this recommendation is 180 days or less. The policy is implemented through the default app management policy and applies to all applications unless scoped exceptions are configured.

The setting does not retroactively shorten or invalidate existing certificate credentials; certificates uploaded before the policy was enabled remain valid until they expire or are explicitly removed.

The recommended state is **Restrict maximum certificate lifetime** set to **On: 180 days or less**.

#### Rationale

Long-lived certificates extend the window of exploitation if a credential is compromised. A certificate valid for multiple years that is never rotated remains usable even if the private key was exposed through a server breach, misconfigured storage, or supply-chain compromise long after the initial exposure. Enforcing a maximum lifetime of 180 days ensures that certificates expire on a regular basis, limiting the period during which a stolen credential remains valid and reducing the blast radius of a compromise. This control also encourages teams to establish automated certificate rotation practices, which further reduces reliance on static, long-lived credentials.

#### Impact

Any automated process, pipeline, or script that uploads certificates with a validity period exceeding the configured maximum will be blocked once the policy is enabled, unless an exception is configured. Organizations will need to update certificate issuance workflows to generate certificates with expiration dates within the allowed range and establish rotation processes for certificates approaching expiry.

#### Remediation action

To remediate using the UI:

1. Navigate to [Microsoft Entra admin center](https://entra.microsoft.com).
2. Expand **Entra ID** and select **Enterprise apps**.
3. Under **Security** select [**Application policies**](https://aka.ms/app-mgmt-policy-ux).
4. Select **Restrict max certificate lifetime**.
5. Set **Status** to **On**.
6. Set **Applies to** to one of the following:
    * **All applications**
    * **All applications with exclusions** (if using exclusions, ensure they are reviewed annually).
7. Set **Only apply to apps created after** to a desired date or leave it unconfigured.
8. Set **Maximum lifetime (in days)** to **180** days or less.
9. Select **Save and close** to apply the changes.

To remediate using the Microsoft Graph API:

1. Execute a **GET** request to retrieve the current policy: `v1.0/policies/defaultAppManagementPolicy`
2. Modify the returned JSON to reflect the following changes:
   * Set `isEnabled` to `true`.
   * Under `applicationRestrictions.keyCredentials`, locate the entry where `restrictionType` is `asymmetricKeyLifetime` and set the following:
      * `state` to `enabled`
      * `maxLifetime` to `P180D` or a shorter duration.
      * `restrictForAppsCreatedAfterDateTime` to `0001-01-01T00:00:00Z` or a desired date.
   * Under `servicePrincipalRestrictions.keyCredentials`, locate the entry where `restrictionType` is `asymmetricKeyLifetime` and set the following:
      * `state` to `enabled`
      * `maxLifetime` to `P180D` or a shorter duration.
      * `restrictForAppsCreatedAfterDateTime` to `0001-01-01T00:00:00Z` or a desired date.
3. Execute a **PATCH** request to the same URI with the modified JSON in the request body to apply the changes.

> **Note:** The PATCH request replaces the `keyCredentials` arrays in full. Include every existing entry from the policy you retrieved so that other restrictions are kept.

> **Note:** Maester also checks that the restriction covers every existing application and service principal. Objects created before the **Only apply to apps created after** date (`restrictForAppsCreatedAfterDateTime`) are exempt from the restriction, so the check fails while any exist. Leave the date unconfigured or set it to `0001-01-01T00:00:00Z`, or to a date before your oldest application and service principal.

#### Related links

* [Microsoft Entra admin center - Application policies](https://aka.ms/app-mgmt-policy-ux)
* [Enforce app management policies in Microsoft Entra ID](https://learn.microsoft.com/graph/api/resources/appmanagementpolicy)
* [Update tenantAppManagementPolicy](https://learn.microsoft.com/graph/api/tenantappmanagementpolicy-update)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.5.6](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
