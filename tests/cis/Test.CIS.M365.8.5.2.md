Anonymous users are people who join a meeting without signing in to Microsoft Teams, and dial-in callers join by phone. If either can start a meeting, it can begin without anyone from the organization present, so nobody who is responsible for the meeting is there to control it.

When the setting is off, anonymous users and dial-in callers wait in the lobby until someone from your organization, a guest, or a user from a trusted organization starts the meeting. The setting only has an effect when **Who can bypass the lobby** is set to **Everyone**. If anonymous users can't join meetings, it applies only to dial-in callers.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Settings & policies** > [**Global (Org-wide default) settings**](https://admin.teams.microsoft.com/one-policy/settings) and select **Meetings**.
3. Under **Meeting join & lobby**, set **Anonymous users and dial-in callers can start a meeting** to **Off**.
4. Select **Save**.

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
