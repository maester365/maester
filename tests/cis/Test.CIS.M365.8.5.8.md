External meeting chat lets users in a meeting chat with people from organizations that are not trusted. Messages from untrusted senders can carry phishing links or malicious files into a meeting that your users are attending.

Turning this off keeps meeting chat to people you trust. Users can still chat with people in your organization and in trusted organizations.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Meetings** > **Meeting policies**.
3. Open the **Global (Org-wide default)** policy.
4. Under **Chat with people in untrusted organizations**, select **Off**.
5. Select **Save**.

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
