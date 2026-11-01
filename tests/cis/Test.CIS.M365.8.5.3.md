Only invited people, people in your organization, or organizers and co-organizers can bypass the meeting lobby.

The lobby lets an organizer, co-organizer or presenter see who is joining before admitting them. For meetings that may contain sensitive information, people who weren't invited directly should wait to be admitted, and anonymous users shouldn't be able to use a meeting link to hold meetings at unscheduled times. People outside the organization, and anyone who dials in, including internal users who are unauthenticated when dialing in, wait in the lobby until someone admits them.

The test passes when **Who can bypass the lobby** in the Global (Org-wide default) meeting policy is **People who were invited** (`InvitedUsers`), **People in my org** (`EveryoneInCompanyExcludingGuests`) or **Only organizers and co-organizers** (`OrganizerOnly`).

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Settings & policies** > [**Global (Org-wide default) settings**](https://admin.teams.microsoft.com/one-policy/settings) and select **Meetings**.
3. Under **Meeting join & lobby**, set **Who can bypass the lobby** to **People who were invited**, **People in my org** or **Only organizers and co-organizers**.
4. Select **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run one of the following commands:

```powershell
Set-CsTeamsMeetingPolicy -Identity Global -AutoAdmittedUsers "InvitedUsers"
Set-CsTeamsMeetingPolicy -Identity Global -AutoAdmittedUsers "EveryoneInCompanyExcludingGuests"
Set-CsTeamsMeetingPolicy -Identity Global -AutoAdmittedUsers "OrganizerOnly"
```

#### Related links

* [Microsoft Teams admin center - Settings & policies](https://admin.teams.microsoft.com/one-policy/settings)
* [Overview of lobby settings and policies](https://learn.microsoft.com/microsoftteams/who-can-bypass-meeting-lobby#overview-of-lobby-settings-and-policies)
* [Set-CsTeamsMeetingPolicy](https://learn.microsoft.com/powershell/module/microsoftteams/set-csteamsmeetingpolicy)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.5.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
