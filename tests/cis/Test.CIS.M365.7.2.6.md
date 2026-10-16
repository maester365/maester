The SharePoint allow list or block list decides which external domains can receive shared content. Without a domain list, a user can share SharePoint files and sites with any external domain, including domains that the organization does not trust or that an attacker controls.

Limiting external sharing to an allow list of approved domains keeps shared content with partners you have agreed to work with. Sharing with other domains is blocked until the domain is added to the list.

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
* [Set-PnPTenant](https://pnp.github.io/powershell/cmdlets/Set-PnPTenant.html)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 7.2.6](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
