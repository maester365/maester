The presenter role controls who can share their screen or content in a meeting. If every participant can take over the presenter role, anyone who joins can share content with the whole meeting, including malicious files, links and screens that show confidential information.

Limiting the presenter role to organizers and co-organizers keeps control of shared content with the people who run the meeting. Everyone else joins as an attendee. The policy sets the default for new meetings, and an organizer can still change who can present in the meeting options of a particular meeting.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Settings & policies** > [**Global (Org-wide default) settings**](https://admin.teams.microsoft.com/one-policy/settings) and select **Meetings**.
3. Under **Content sharing**, set **Who can present** to **Only organizers and co-organizers**.
4. Select **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command:

```powershell
Set-CsTeamsMeetingPolicy -Identity Global -DesignatedPresenterRoleMode OrganizerOnlyUserOverride
```

#### Related links

* [Microsoft Teams admin center](https://admin.teams.microsoft.com)
* [Manage meeting policies in Microsoft Teams](https://learn.microsoft.com/microsoftteams/meeting-policies-in-teams)
* [Set-CsTeamsMeetingPolicy](https://learn.microsoft.com/powershell/module/teams/set-csteamsmeetingpolicy)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.5.6](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
