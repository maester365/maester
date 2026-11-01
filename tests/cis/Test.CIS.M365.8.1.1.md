Teams lets users share files only through third-party cloud storage services that the organization has approved.

Teams stores and shares files in SharePoint and OneDrive by default, but it can also open files from Dropbox, Box, Google Drive, Citrix ShareFile and Egnyte. Files in those services are outside the organization's data protection, retention and sharing controls, and the services may not meet the organization's security standards. Turning off the services that aren't approved keeps users on storage the organization governs. Users who rely on another provider lose access to it from Teams.

The test reads the Global Teams client configuration and fails when a service is on that the organization has not approved. List approved services in the `ApprovedProviders` parameter (`Dropbox`, `Box`, `GoogleDrive`, `ShareFile`, `Egnyte`); by default none are approved.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Settings & policies** > [**Global (Org-wide default) settings**](https://admin.teams.microsoft.com/one-policy/settings) and select **Teams** to open the **Teams settings** section.
3. Under **Files**, turn off each storage provider that the organization has not authorized.
4. Select **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command, leaving out any provider that the organization has authorized:

```powershell
$params = @{
    Identity         = 'Global'
    AllowGoogleDrive = $false
    AllowShareFile   = $false
    AllowBox         = $false
    AllowDropBox     = $false
    AllowEgnyte      = $false
}
Set-CsTeamsClientConfiguration @params
```

#### Related links

* [Microsoft Teams admin center - Settings & policies](https://admin.teams.microsoft.com/one-policy/settings)
* [Set-CsTeamsClientConfiguration](https://learn.microsoft.com/powershell/module/microsoftteams/set-csteamsclientconfiguration)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.1.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
