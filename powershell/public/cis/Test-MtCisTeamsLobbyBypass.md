8.5.3 (L1) Ensure only people in my org can bypass the lobby

This test checks if the Global (Org-wide default) meeting policy is configured to only bypass the lobby for 'Peoply in my org'.

This policy setting controls who can join a meeting directly and who must wait in the lobby until they're admitted by an organizer, co-organizer, or presenter of the meeting.

Rationale:\
For meetings that could contain sensitive information, it is best to allow the meeting organizer to vet anyone not directly sent an invite before admitting them to the meeting. This will also prevent the anonymous user from using the meeting link to have meetings at unscheduled times.

#### Remediation action:

To change who can bypass the lobby using the UI:
1. Navigate to [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Click to expand **Meetings** select **Meeting policies**.
3. Click **Global (Org-wide default)**.
4. Seach for **Meeting join & lobby**.
5. Set **Who can bypass the lobby** to **People in my org**.
6. Click **Save**.

To change who can bypass the lobby using PowerShell:
1. Connect to Teams using **Connect-MicrosoftTeams**.
2. Run following PowerShell Command:
```
Set-CsTeamsMeetingPolicy -Identity Global -AutoAdmittedUsers "EveryoneInCompanyExcludingGuests"
```

#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [Microsoft Teams Admin Center](https://admin.teams.microsoft.com).
* [Overview of lobby settings and policies](https://learn.microsoft.com/en-us/microsoftteams/who-can-bypass-meeting-lobby#overview-of-lobby-settings-and-policies)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 400](https://www.cisecurity.org/benchmark/microsoft_365)
* [CISA MS.TEAMS.1.4v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/teams.md#msteams14v1)

<!--- Results --->
%TestResult%