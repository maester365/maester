7.3.1 (L2) Ensure Office 365 SharePoint infected files are disallowed for download

By default, SharePoint online allows files that Defender for Office 365 has detected as infected to be downloaded.

## Rationale

Defender for Office 365 for SharePoint, OneDrive, and Microsoft Teams protects your organization from inadvertently sharing malicious files. When an infected file is detected that file is blocked so that no one can open, copy, move, or share it until further actions are taken by the organization's security team.

## Impact

The only potential impact associated with implementation of this setting is potential inconvenience associated with the small percentage of false positive detections that may occur.

## Remediation

### PowerShell

1. Connect to SharePoint Online using `Connect-SPOService -Url https://tenant-admin.sharepoint.com`, replacing "tenant" with the appropriate value.
2. Run the following PowerShell command to set the recommended value:

```powershell
Set-SPOTenant –DisallowInfectedFileDownload $true
```

>Note: The Global Reader role cannot access SharePoint using PowerShell according to Microsoft. See the reference section for more information.

>Default Value: False

## Related Links

* [Manage sharing settings for SharePoint and OneDrive in Microsoft 365](https://learn.microsoft.com/en-us/sharepoint/turn-external-sharing-on-or-off#change-the-organization-level-external-sharing-setting)
* [Overview of external sharing in SharePoint and OneDrive in Microsoft 365](https://learn.microsoft.com/en-us/sharepoint/external-sharing-overview)
* [CIS Microsoft 365 Foundations Benchmark v6.0.1 - Page 394](https://www.cisecurity.org/benchmark/microsoft_365)