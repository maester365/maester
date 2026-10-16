OneDrive is the personal file storage of each user. When sharing from OneDrive is open, users can give files to anyone, including people outside the organization, and the owner of the file may not notice. Sensitive personal and work files then leave the tenant through links that are hard to track.

Turning off sharing from OneDrive means users can share their OneDrive files only inside the organization. Files that must reach external people can be moved to a SharePoint site where sharing is governed by the tenant policy.

#### Remediation action

1. Sign in to the [SharePoint admin center](https://admin.microsoft.com/sharepoint).
2. Go to **Policies** > **Sharing**.
3. Expand **More external sharing settings**.
4. Under **OneDrive**, select **Only people in your organization**.
5. Select **Save**.

To apply the setting with PowerShell, connect with `Connect-PnPOnline -Url https://<tenant>-admin.sharepoint.com -Interactive` and run the following for the OneDrive site (replace the URL with the OneDrive site address):

```powershell
Set-PnPTenantSite -Url https://<tenant>-my.sharepoint.com/ -SharingCapability Disabled
```

#### Related links

* [SharePoint admin center](https://admin.microsoft.com/sharepoint)
* [Turn external sharing on or off](https://learn.microsoft.com/sharepoint/turn-external-sharing-on-or-off)
* [Set-PnPTenantSite](https://pnp.github.io/powershell/cmdlets/Set-PnPTenantSite.html)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 7.2.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
