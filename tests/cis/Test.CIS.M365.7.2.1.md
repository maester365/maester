SharePoint Online can accept sign-ins from legacy authentication protocols. Those protocols do not support multifactor authentication or conditional access, so anyone who obtains or sprays a password can reach SharePoint content without a second factor.

Blocking legacy protocols makes SharePoint sign-in use modern authentication only. Older clients and scripts that depend on basic authentication stop working until they are updated.

#### Remediation action

1. Sign in to the [SharePoint admin center](https://admin.microsoft.com/sharepoint).
2. Go to **Policies** > **Access control**.
3. Under **Apps that don't use modern authentication**, select **Block access**.
4. Select **Save**.

To apply the same setting with PowerShell, connect with `Connect-PnPOnline -Url https://<tenant>-admin.sharepoint.com -Interactive` and run:

```powershell
Set-PnPTenant -LegacyAuthProtocolsEnabled $false
```

#### Related links

* [SharePoint admin center](https://admin.microsoft.com/sharepoint)
* [Set-PnPTenant](https://pnp.github.io/powershell/cmdlets/Set-PnPTenant.html)
* [Block legacy authentication](https://learn.microsoft.com/entra/identity/conditional-access/block-legacy-authentication)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 7.2.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
