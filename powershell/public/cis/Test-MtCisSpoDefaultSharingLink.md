7.2.7 (L1) Ensure link sharing is restricted in SharePoint and OneDrive

This setting sets the default link type that a user will see when sharing content in OneDrive or SharePoint. It does not restrict or exclude any other options. The recommended state is **Specific people (only the people the user specifies) or Only people in your organization** (more restrictive).

## Rationale

By defaulting to specific people, the user will first need to consider whether or not the content being shared should be accessible by the entire organization versus select individuals. This aids in reinforcing the concept of least privilege.

## Impact

Changing the default sharing link type influences the user experience when sharing files and folders in SharePoint and OneDrive. The configured default option will appear pre-selected in the sharing dialog, guiding users toward the organization's preferred sharing method.

## Remediation

1. Navigate to [SharePoint admin center](https://admin.microsoft.com/sharepoint)
2. Click to expand **Policies** > **Sharing**.
3. Scroll to **File and folder links.**
4. Set **Choose the type of link that's selected by default when users share files and folders in SharePoint and OneDrive to Specific people (only the people the user specifies) or Only people in your organization.**

### PowerShell

1. Connect to SharePoint Online using `Connect-SPOService`
2. Run the following command:

```powershell
Set-SPOTenant -DefaultSharingLinkType Direct
```

1. Or, to set a more restrictive state:

```powershell
Set-SPOTenant -DefaultSharingLinkType Internal
```

>Default Value: Only people in your organization (Internal)

## Related Links

* [Set-SPOTenant](https://learn.microsoft.com/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant?view=sharepoint-ps)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - Page 480](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
