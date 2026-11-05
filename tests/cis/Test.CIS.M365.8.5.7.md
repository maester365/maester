Giving or requesting control lets a participant take over the screen or a shared application of another participant. If external participants can do this, a guest from another organization can gain control of a presenter's desktop or content during a meeting.

Turning this off means external participants can't give or request control of shared content. External participants who are allowed to present can still share their own screen, which the **Who can present** setting controls. Control of your organization's shared screens stays with participants from your organization.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Settings & policies** > [**Global (Org-wide default) settings**](https://admin.teams.microsoft.com/one-policy/settings) and select **Meetings**.
3. Under **Content sharing**, set **External participants can give or request control** to **Off**.
4. Select **Save**.

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
