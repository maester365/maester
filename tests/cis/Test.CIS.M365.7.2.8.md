External sharing in SharePoint Online can be open to every external user in the tenant. A security group limits external sharing to the people you have explicitly approved, so an external guest who is not in the group cannot be given access to content through sharing.

Restricting sharing to a security group keeps external access under the control of the group owner. Other external sharing is blocked until the user is added to the group.

#### Remediation action

1. Create or choose a Microsoft Entra security group that contains the users who may receive external shares.
2. Sign in to the [SharePoint admin center](https://admin.microsoft.com/sharepoint).
3. Go to **Policies** > **Sharing**.
4. Expand **More external sharing settings**.
5. Select **Limit external sharing to specific security groups** and choose the group.
6. Select **Save**.

To apply the setting with PowerShell, connect with `Connect-PnPOnline -Url https://<tenant>-admin.sharepoint.com -Interactive` and run the following, replacing the group ID with the object ID of your security group:

```powershell
Set-PnPTenant -GuestSharingGroupAllowListInTenantByPrincipalIdentity '<group object id>'
```

#### Related links

* [SharePoint admin center](https://admin.microsoft.com/sharepoint)
* [External sharing overview](https://learn.microsoft.com/sharepoint/external-sharing-overview)
* [Set-PnPTenant](https://pnp.github.io/powershell/cmdlets/Set-PnPTenant.html)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 7.2.8](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
