Meeting recordings can capture confidential discussion, shared screens and personal information. While recording is allowed, anyone with recording permission can start one, and the recording is then stored and shared under the organization's retention rules.

Turning meeting recording off in the Global policy means nobody who has that policy can record a meeting. Users who need to record are assigned a separate meeting policy that allows it, so the permission is given on purpose instead of to everyone by default.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Settings & policies** > [**Global (Org-wide default) settings**](https://admin.teams.microsoft.com/one-policy/settings) and select **Meetings**.
3. Under **Recording & transcription**, set **Meeting recording** to **Off**.
4. Select **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command:

```powershell
Set-CsTeamsMeetingPolicy -Identity Global -AllowCloudRecording $false
```

#### Related links

* [Microsoft Teams admin center](https://admin.teams.microsoft.com)
* [Manage meeting policies in Microsoft Teams](https://learn.microsoft.com/microsoftteams/meeting-policies-in-teams)
* [Set-CsTeamsMeetingPolicy](https://learn.microsoft.com/powershell/module/teams/set-csteamsmeetingpolicy)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.5.9](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
