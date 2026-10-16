Anonymous users are people who join a meeting without signing in to Microsoft Teams. If they can start a meeting, the meeting is opened by an unknown party, so the organizer and the organization have no assurance of who is in control.

Turning off anonymous start means a meeting can only be started by a signed-in person from your organization or a trusted partner. Meetings that anonymous users join still need a signed-in organizer.

This test checks only the Global meeting policy setting AllowAnonymousUsersToStartMeeting. It does not check dial-in callers, so a pass does not show that dial-in callers are prevented from starting a meeting.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Meetings** > **Meeting policies**.
3. Open the **Global (Org-wide default)** policy.
4. Under **Anonymous users can start a meeting**, select **Off**.
5. Select **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command:

```powershell
Set-CsTeamsMeetingPolicy -Identity Global -AllowAnonymousUsersToStartMeeting $false
```

#### Related links

* [Microsoft Teams admin center](https://admin.teams.microsoft.com)
* [Manage meeting policies in Microsoft Teams](https://learn.microsoft.com/microsoftteams/meeting-policies-in-teams)
* [Set-CsTeamsMeetingPolicy](https://learn.microsoft.com/powershell/module/teams/set-csteamsmeetingpolicy)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.5.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
