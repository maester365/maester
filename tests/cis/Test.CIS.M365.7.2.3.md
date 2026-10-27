External content sharing in SharePoint Online decides who outside the organization can receive files and sites. If sharing is open to anyone, a link can be forwarded to people who are not known to the tenant, and content can leave the organization without an account check.

Restricting sharing to new and existing guests, existing guests only, or turning external sharing off, means that only people who sign in with a guest account in your directory can receive shared content. Anyone links stop working, and users keep working with their guests.

In commercial tenants, Microsoft Entra B2B integration is enabled by default for new external sharing. This changes how external users are invited, not the SharePoint sharing level checked here. This test does not verify the guest's authentication method or whether a matching guest account exists.

#### Remediation action

1. Sign in to the [SharePoint admin center](https://admin.microsoft.com/sharepoint).
2. Go to **Policies** > **Sharing**.
3. Under **External sharing**, move the slider to **New and existing guests** or **Existing guests**, or to **Only people in your organization** to turn external sharing off.
4. Select **Save**.

To apply the setting with PowerShell, connect with `Connect-PnPOnline -Url https://<tenant>-admin.sharepoint.com -Interactive` and run:

```powershell
Set-PnPTenant -SharingCapability ExternalUserSharingOnly
```

#### Related links

* [SharePoint admin center](https://admin.microsoft.com/sharepoint)
* [Turn external sharing on or off](https://learn.microsoft.com/sharepoint/turn-external-sharing-on-or-off)
* [External sharing overview](https://learn.microsoft.com/sharepoint/external-sharing-overview)
* [Microsoft Entra B2B integration for SharePoint and OneDrive](https://learn.microsoft.com/en-us/sharepoint/sharepoint-azureb2b-integration)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 7.2.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
