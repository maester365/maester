5.1.8.1 (L1) Ensure that password hash sync is enabled for hybrid deployments

Password Hash Synchronization is one of the sign-in methods used to enable hybrid identity authentication. With this method, Microsoft Entra Connect synchronizes a cryptographically derived representation of a user's on-premises Active Directory password to Microsoft Entra ID.

The original NT password hash (MD4) is never transmitted to Entra ID. Instead, Entra Connect computes a SHA-256 hash of the original MD4 hash and synchronizes that value. Because only this secondary hash is stored in the cloud, the credential material in Entra ID cannot be reused for on-premises pass-the-hash attacks, even if compromised.

> **Note:** This recommendation applies only to Microsoft 365 tenants operating in a hybrid identity configuration using Microsoft Entra Connect. It does not apply to federated or cloud-only deployments.

#### Rationale

Password hash synchronization helps by reducing the number of passwords your users need to maintain to just one and enables leaked credential detection for your hybrid accounts. Leaked credential protection is leveraged through Entra ID Protection and is a subset of that feature which can help identify if an organization's user account passwords have appeared on the dark web or public spaces.

Using other options for your directory synchronization may be less resilient as Microsoft can still process sign-ins to 365 with Hash Sync even if a network connection to your on-premises environment is not available. This minimizes downtime and ensures business continuity.

#### Impact

Compliance or regulatory restrictions may exist, depending on the organization's business sector, that preclude hashed versions of passwords from being securely transmitted to cloud data centers.

#### Remediation action:

To remediate using the on-premises Microsoft Entra Connect tool:

1. Log in to the on-premises server that hosts the Microsoft Entra Connect tool.
2. Double-click the **Azure AD Connect** icon that was created on the desktop.
3. Click **Configure**.
4. On the **Additional tasks** page, select **Customize synchronization options** and click **Next**.
5. Enter the username and password for your global administrator.
6. On the **Connect your directories** screen, click **Next**.
7. On the **Domain and OU filtering** screen, click **Next**.
8. On the **Optional features** screen, check **Password hash synchronization** and click **Next**.
9. On the **Ready to configure** screen, click **Configure**.
10. Once the configuration completes, click **Exit**.

> **Note:** Microsoft Entra Connect sync is disabled by default. Password Hash Sync is Microsoft's recommended setting for new deployments.

#### Related links

* [Microsoft Entra admin center](https://entra.microsoft.com)
* [What is password hash synchronization with Microsoft Entra ID?](https://learn.microsoft.com/entra/identity/hybrid/connect/whatis-phs)
* [Implement password hash synchronization with Microsoft Entra Connect Sync](https://learn.microsoft.com/entra/identity/hybrid/connect/how-to-connect-password-hash-synchronization)
* [Microsoft Entra Connect Sync: Staging server and disaster recovery](https://learn.microsoft.com/entra/identity/hybrid/connect/how-to-connect-sync-staging-server)
* [onPremisesDirectorySynchronizationFeature resource type](https://learn.microsoft.com/graph/api/resources/onpremisesdirectorysynchronizationfeature?view=graph-rest-1.0)
* [Download Microsoft Entra Connect](https://www.microsoft.com/download/details.aspx?id=47594)
* [CIS Microsoft 365 Foundations Benchmark - Page 278](https://www.cisecurity.org/benchmark/microsoft_365)


<!--- Results --->
%TestResult%
