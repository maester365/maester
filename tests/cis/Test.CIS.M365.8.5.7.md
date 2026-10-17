Giving or requesting control lets a participant take over the screen or a shared application of another participant. If external participants can do this, a guest from another organization can gain control of a presenter's desktop or content during a meeting.

Turning this off means external participants can only view shared content. Control stays with participants from your organization.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Meetings** > **Meeting policies**.
3. Open the **Global (Org-wide default)** policy.
4. Under **External participants can give or request control**, select **Off**.
5. Select **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command:

```powershell
Set-CsTeamsMeetingPolicy -Identity Global -AllowExternalParticipantGiveRequestControl $false
```

#### Related links

* [Microsoft Teams admin center](https://admin.teams.microsoft.com)
* [Manage meeting policies in Microsoft Teams](https://learn.microsoft.com/microsoftteams/meeting-policies-in-teams)
* [Set-CsTeamsMeetingPolicy](https://learn.microsoft.com/powershell/module/teams/set-csteamsmeetingpolicy)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.5.7](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
