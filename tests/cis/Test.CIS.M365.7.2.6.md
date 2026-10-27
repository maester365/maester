The SharePoint allow list or block list decides which external domains can receive shared content. Without a domain list, a user can share SharePoint files and sites with any external domain, including domains that the organization does not trust or that an attacker controls, which makes it an easy route for sending data out of the tenant.

Limiting external sharing to an allow list of approved domains keeps shared content with partners you have agreed to work with. Sharing with other domains is blocked until the domain is added to the list. The domain list applies to sharing with named guests, not to Anyone links, so turn off Anyone links as well (CIS 7.2.3) if content must stay with approved partners. Agree the list of partner domains with the teams that share content before you turn the restriction on.

When using Entra B2B integration, review any custom SharePoint and OneDrive domain restrictions and decide whether to move them to the Microsoft Entra B2B Allow/Deny list. This test checks the SharePoint restriction only; it does not verify the Entra list, which can also affect Teams and Microsoft 365 Groups.

#### Remediation action

1. Sign in to the [SharePoint admin center](https://admin.microsoft.com/sharepoint).
2. Go to **Policies** > **Sharing**.
3. Expand **More external sharing settings**.
4. Select **Limit external sharing by domain**, then select **Allow only specific domains**.
5. Add the approved domains and select **Save**.

To apply the setting with PowerShell, connect with `Connect-PnPOnline -Url https://<tenant>-admin.sharepoint.com -Interactive` and run the following, replacing the example domains with your approved domains:

```powershell
Set-PnPTenant -SharingDomainRestrictionMode AllowList -SharingAllowedDomainList 'partner.example.com contoso.example.org'
```

#### Related links

* [SharePoint admin center](https://admin.microsoft.com/sharepoint)
* [Restrict sharing of SharePoint and OneDrive content by domain](https://learn.microsoft.com/sharepoint/restricted-domains-sharing)
* [Microsoft Entra B2B integration for SharePoint and OneDrive](https://learn.microsoft.com/en-us/sharepoint/sharepoint-azureb2b-integration)
* [Set-PnPTenant](https://pnp.github.io/powershell/cmdlets/Set-PnPTenant.html)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 7.2.6](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
