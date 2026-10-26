Channel email addresses let a user send an email into a Teams channel. An attacker who learns or guesses such an address can post content into the channel, which members may trust because it appears in the team. Blocking this removes a path for unsolicited and phishing content into channels.

When the setting is off, channel members can still post in Teams. Only the email-to-channel entry point is closed, so users who relied on it need another way to share content.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Teams** > **Teams settings**.
3. Under **Email integration**, turn off **Users can send emails to a channel email address**.
4. Select **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command:

```powershell
Set-CsTeamsClientConfiguration -Identity Global -AllowEmailIntoChannel $false
```

#### Related links

* [Microsoft Teams admin center](https://admin.teams.microsoft.com)
* [Set-CsTeamsClientConfiguration (AllowEmailIntoChannel)](https://learn.microsoft.com/powershell/module/teams/set-csteamsclientconfiguration)
* [Set-CsTeamsClientConfiguration](https://learn.microsoft.com/powershell/module/teams/set-csteamsclientconfiguration)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.1.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
