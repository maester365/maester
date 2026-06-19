7.2.11 (L1) Ensure the SharePoint default sharing link permission is set

This setting configures the permission that is selected by default for sharing link from a SharePoint site.

The recommended state is **View**.

## Rationale

Setting the view permission as the default ensures that users must deliberately select the edit permission when sharing a link. This approach reduces the risk of unintentionally granting edit privileges to a resource that only requires read access, supporting the principle of least privilege.

## Impact

Not applicable.

## Remediation

1. Navigate to [SharePoint admin center](https://admin.microsoft.com/sharepoint)
2. Click to expand **Policies** > **Sharing**.
3. Scroll to **File and folder links.**
4. Ensure **Choose the permission that's selected by default for sharing links** is set to **View**.

### PowerShell

1. Connect to SharePoint Online using `Connect-SPOService`
2. Run the following command:

```powershell
Set-SPOTenant -DefaultLinkPermission View
```

>Default Value: DefaultLinkPermission : Edit

## Related Links

* [Manage sharing settings for SharePoint and OneDrive in Microsoft 365](https://learn.microsoft.com/en-us/sharepoint/turn-external-sharing-on-or-off#file-and-folder-links)
* [CIS Microsoft 365 Foundations Benchmark v6.0.1 - Page 391](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
