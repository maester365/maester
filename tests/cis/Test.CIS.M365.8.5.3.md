Only invited people, people in your organization, or organizers and co-organizers can bypass the meeting lobby.

The lobby lets an organizer, co-organizer or presenter see who is joining before admitting them. With **People who were invited** (`InvitedUsers`), invited external participants can bypass the lobby, including people who receive a forwarded invitation and invitees on a distribution list. People who have only the meeting link, but no invitation, and participants who are not signed in must wait in the lobby. Choose **People in my org** or **Only organizers and co-organizers** if invited external participants should also wait.

This test checks only the Global meeting policy default; organizers can change **Who can bypass the lobby** in Meeting options. Phone dial-in callers use the separate **People dialing in can bypass the lobby** setting, which organizers can also change in Meeting options. When that setting is on, callers may bypass the lobby after the meeting starts even when this test passes. Review the dial-in setting separately.

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
