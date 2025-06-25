8.1.1 (L2) Ensure external file sharing in Teams is enabled for only approved cloud storage services

This test checks if the third-party cloud services are disabled.
- DropBox
- Box
- Google Drive
- Citrix Files
- Egnyte

Microsoft Teams enables collaboration via file sharing. This file sharing is conducted within Teams, using SharePoint Online, by default; however, third-party cloud services are allowed as well.

Rationale:\
Ensuring that only authorized cloud storage providers are accessible from Teams will help to dissuade the use of non-approved storage providers

#### Remediation action:

To change third-party cloud services using the UI:
1. Navigate to **Microsoft Teams admin center** [https://admin.teams.microsoft.com](https://admin.teams.microsoft.com).
2. Click to expand **Teams** select **Teams settings**.
3. Scroll to **Files**.
4. Set any unauthorized provider to **Off**.

To change third-party cloud services using PowerShell:
1. Connect to Teams using **Connect-MicrosoftTeams**.
2. Run following PowerShell Command:
```
$storageParams = @{
 AllowDropBox = $false
 AllowBox = $false
 AllowGoogleDrive = $false
 AllowShareFile = $false
 AllowEgnyte = $false
}
Set-CsTeamsClientConfiguration @storageParams
```

#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [Microsoft Teams Admin Center](https://admin.teams.microsoft.com).
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 369](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%