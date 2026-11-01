External meeting chat lets your users read and write chat messages in meetings that are hosted by organizations you have no trusted relationship with. Messages from untrusted senders can carry phishing links or malicious files into a meeting that your users are attending.

Turning this off keeps your users out of the chat in meetings hosted by untrusted organizations. Users can still chat in meetings hosted by your organization and by trusted organizations.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Settings & policies** > [**Global (Org-wide default) settings**](https://admin.teams.microsoft.com/one-policy/settings) and select **Meetings**.
3. Under **Meeting engagement**, set **External meeting chat** to **Off**.
4. Select **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command:

```powershell
Set-CsTeamsMeetingPolicy -Identity Global -AllowExternalNonTrustedMeetingChat $false
```

#### Related links

* [Microsoft Teams admin center](https://admin.teams.microsoft.com)
* [Manage meeting policies in Microsoft Teams](https://learn.microsoft.com/microsoftteams/meeting-policies-in-teams)
* [Set-CsTeamsMeetingPolicy](https://learn.microsoft.com/powershell/module/teams/set-csteamsmeetingpolicy)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.5.8](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
