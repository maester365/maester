This test checks if any app registration uses a certificate that was issued with an excessive validity period.

Certificates are the recommended alternative to client secrets, but a certificate that is valid for several years reintroduces the risk it was meant to remove: a stolen private key stays usable for the entire remaining validity period, and long-lived credentials are rarely rotated or reviewed.

An app management policy does not close this gap on its own. Credential restrictions carry a `restrictForAppsCreatedAfterDateTime` property and only apply to credentials added after the policy takes effect, so certificates that already exist are grandfathered in and are never re-evaluated. A tenant can therefore pass the app management policy test and still authenticate with multi-year certificates.

Certificates that have already expired can no longer be used to authenticate and are not reported by this test.

#### Remediation action

1. Open the app registration listed below in the [Microsoft Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade) and select **Certificates & secrets**.
2. Request or generate a replacement certificate with a shorter validity period and upload it under **Certificates**.
3. Update the workload that authenticates with the app registration to use the new certificate.
4. Once the workload has been confirmed to work, delete the long-lived certificate.
5. Configure the [default app management policy](https://learn.microsoft.com/graph/api/resources/tenantappmanagementpolicy) with an `asymmetricKeyLifetime` restriction so that new certificates cannot be added with an excessive validity period.
6. Where possible, replace certificate authentication with a [managed identity](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview) or [workload identity federation](https://learn.microsoft.com/entra/workload-id/workload-identity-federation), which removes the credential entirely.

## Learn more

- [Microsoft Entra application management policies API overview](https://learn.microsoft.com/graph/api/resources/applicationauthenticationmethodpolicy)
- [Tenant app management policy - Microsoft Graph reference](https://learn.microsoft.com/graph/api/resources/tenantappmanagementpolicy)
- [Workload identity federation](https://learn.microsoft.com/entra/workload-id/workload-identity-federation)
- [Microsoft Entra recommendation: Remove unused credentials from applications](https://learn.microsoft.com/entra/identity/monitoring-health/recommendation-remove-unused-credential-from-apps)

<!--- Results --->

%TestResult%
