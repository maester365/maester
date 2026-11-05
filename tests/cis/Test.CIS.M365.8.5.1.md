Anonymous users are people who join a meeting without signing in to Microsoft Teams. If anonymous users can join, anyone who has the meeting link, or who finds it forwarded or posted in public, can attend and listen to or take part in confidential discussions.

Turning off anonymous join keeps meetings limited to people who have signed in. Users who must attend without an account can still be invited through a supported path, such as a guest account.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Settings & policies** > [**Global (Org-wide default) settings**](https://admin.teams.microsoft.com/one-policy/settings) and select **Meetings**.
3. Under **Meeting join & lobby**, set **Anonymous users can join a meeting unverified** to **Off**.
4. Select **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command:

```powershell
Set-CsTeamsMeetingPolicy -Identity Global -AllowAnonymousUsersToJoinMeeting $false
```

#### Related links

* [Microsoft Teams admin center](https://admin.teams.microsoft.com)
* [Manage meeting policies in Microsoft Teams](https://learn.microsoft.com/microsoftteams/meeting-policies-in-teams)
* [Set-CsTeamsMeetingPolicy](https://learn.microsoft.com/powershell/module/teams/set-csteamsmeetingpolicy)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.5.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
