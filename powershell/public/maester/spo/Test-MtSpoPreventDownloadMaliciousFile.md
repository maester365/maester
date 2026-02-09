7.3.1 (L2) Ensure Office 365 SharePoint infected files are disallowed for download

Description:
By default, SharePoint online allows files that Defender for Office 365 has detected as infected to be downloaded.

Rationale:
Defender for Office 365 for SharePoint, OneDrive, and Microsoft Teams protects your organization from inadvertently sharing malicious files. When an infected file is detected that file is blocked so that no one can open, copy, move, or share it until further actions are taken by the organization's security team.

Impact:
The only potential impact associated with implementation of this setting is potential inconvenience associated with the small percentage of false positive detections that may occur.

## Related Links

* [Safe Attachments for SharePoint, OneDrive, and Microsoft Teams](https://learn.microsoft.com/en-us/defender-office-365/safe-attachments-for-spo-odfb-teams-configure?view=o365-worldwide#step-2-recommended-use-sharepoint-online-powershell-to-prevent-users-from-downloading-malicious-files)
* CIS 7.3.1 (L2) Ensure Office 365 SharePoint infected files are disallowed for download