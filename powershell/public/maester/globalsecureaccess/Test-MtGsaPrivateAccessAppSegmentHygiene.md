Entra Private Access application segments should target specific destinations. Broad or risky destinations break least-privilege and can cause operational problems:

* **`dnsSuffix` that is a bare top-level domain** (for example `com`, `net`, `local`) - a TLD-wide catch-all. A normal scoped suffix such as `contoso.com` is the recommended resolution path and is **not** flagged.
* **Wildcard FQDN** (for example `*.contoso.com`).
* **Single-label FQDN** (for example `fileserver`) - relies on the synthetic Global Secure Access suffix and carries a Kerberos SPN risk.
* **Broad IP ranges** (near-default routes). The portal's broadest selectable mask is `/1`, so segments *broader than* `/16` are flagged - a `/16`, common for 10.x networks, still passes. Global Secure Access is IPv4-only, so IPv6 is not evaluated. Finer least-privilege CIDR checks are left to the overlapping ZTA segment check.

`servicePrincipalName` segments (Kerberos SPNs such as `HTTP/*`) are a legitimate Private Access construct and are not evaluated.

#### Remediation action:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a **Global Secure Access Administrator**.
2. Browse to **Global Secure Access** > **Applications** > **Enterprise applications** and open each flagged application.
3. Replace the broad segment with specific FQDNs / IP ranges, and configure the correct Private DNS suffix instead of relying on a `dnsSuffix` catch-all.

#### Related links

* [Configure per-app access using Global Secure Access applications](https://learn.microsoft.com/entra/global-secure-access/how-to-configure-per-app-access)
* [How to configure Quick Access](https://learn.microsoft.com/entra/global-secure-access/how-to-configure-quick-access)

<!--- Results --->
%TestResult%
