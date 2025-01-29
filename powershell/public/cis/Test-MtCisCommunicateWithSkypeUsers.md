8.2.4 (L1) Ensure communication with Skype users is disabled 

This test checks if the communication with Skype users is disabled .

This policy setting controls chat with external unmanaged Skype users. Note: Skype for business is deprecated as of July 31, 2021, although these settings may still be valid for a period of time. See the link in the reference section for more information.

Rationale:\
Skype was deprecated July 31, 2021. Disabling communication with skype users reduces the attack surface of the organization. If a partner organization or satellite office wishes to collaborate and has not yet moved off of Skype, then a valid exception will need to be considered for this recommendation.

#### Remediation action:

To change communication with Skype users using the UI:
1. Navigate to **Microsoft Teams admin center** [https://admin.teams.microsoft.com](https://admin.teams.microsoft.com).
2. Click to expand **Users** select **External access**.
3. Locate **Skype users**
4. Set **Allow users in my organization to communicate with Skype users** to **Off**.
5. Click **Save**

To change communication with Skype users using PowerShell:
1. Connect to Teams using **Connect-MicrosoftTeams**.
2. Run following PowerShell Command:
```
Set-CsTenantFederationConfiguration -AllowPublicUsers $false
```

#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [Microsoft Teams Admin Center](https://admin.teams.microsoft.com).
* [Manage external meetings and chat with people and organizations using Microsoft identities](https://learn.microsoft.com/en-us/microsoftteams/trusted-organizations-external-meetings-chat)
* [CIS Microsoft 365 Foundations Benchmark v4.0.0 - Page 357](https://www.cisecurity.org/benchmark/microsoft_365)
* [CISA MS.TEAMS.3.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/teams.md#msteams14v1)
* [MITRE ATT&CK TTP Mapping](https://attack.mitre.org/techniques/T1567/)

<!--- Results --->
%TestResult%