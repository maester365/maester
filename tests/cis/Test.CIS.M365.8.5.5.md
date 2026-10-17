Meeting chat is open to everyone who is in the meeting. If anonymous users can use it, a person who has joined without signing in can post messages and links to all participants, which is a route for phishing and social engineering during a meeting.

Limiting meeting chat to signed-in participants keeps the chat to people whose identity is known. Anonymous participants can still listen and watch the meeting.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Meetings** > **Meeting policies**.
3. Open the **Global (Org-wide default)** policy.
4. Under **Meeting chat**, select **On for everyone but anonymous users** or **Off**.
5. Select **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command:

```powershell
Set-CsTeamsMeetingPolicy -Identity Global -MeetingChatEnabledType EnabledExceptAnonymous
```

#### Related links

* [Microsoft Teams admin center](https://admin.teams.microsoft.com)
* [Manage meeting policies in Microsoft Teams](https://learn.microsoft.com/microsoftteams/meeting-policies-in-teams)
* [Set-CsTeamsMeetingPolicy](https://learn.microsoft.com/powershell/module/teams/set-csteamsmeetingpolicy)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.5.5](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
