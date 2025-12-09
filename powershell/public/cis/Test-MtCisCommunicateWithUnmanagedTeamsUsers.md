8.2.2 (L1) Ensure communication with unmanaged Teams users is disabled & 8.2.3 (L1) Ensure external Teams users cannot initiate conversations

This test checks if the communication with unmanaged Teams users is disabled .

8.2.2 (L1):\
This policy setting controls chats and meetings with external unmanaged Teams users (those not managed by an organization, such as Microsoft Teams (free))

Rationale:\
Allowing users to communicate with unmanaged Teams users presents a potential security threat as little effort is required by threat actors to gain access to a trial or free Microsoft Teams account.

8.2.3 (L1):\
This setting prevents external users who are not managed by an organization from initiating contact with users in the protected organization.
Note: Disabling this setting is used as an additional stop gap for the previous setting which disables communication with unmanaged Teams users entirely. If an organization chooses to have an exception to (L1) Ensure communication with unmanaged Teams users is disabled they can do so while also disabling the ability for the same group of users to initiate contact. Disabling communication entirely will also disable the ability for unmanaged users to initiate contact.

Rationale:\
Allowing users to communicate with unmanaged Teams users presents a potential security threat as little effort is required by threat actors to gain access to a trial or free Microsoft Teams account.

#### Remediation action:

To change communication with unmanaged Teams users using the UI:
1. Navigate to **Microsoft Teams admin center** [https://admin.teams.microsoft.com](https://admin.teams.microsoft.com).
2. Click to expand **Users** select **External access**.
3. Scroll to **Teams accounts not managed by an organization**.
4. Set **People in my organization can communicate with Teams users whose accounts aren't managed by an organization** to **Off**.
5. Uncheck **External users with Teams accounts not managed by an organization can contact users in my organization**.
    - If **People in my organization can communicate with Teams users whose accounts aren't managed by an organization** is already set to **Off** then this setting will not be visible and can be considered to be in a passing state.
6. Click **Save**

To change communication with unmanaged Teams users using PowerShell:
1. Connect to Teams using **Connect-MicrosoftTeams**.
2. Run following PowerShell Command:
```
Set-CsTenantFederationConfiguration -AllowTeamsConsumer $false
Set-CsTenantFederationConfiguration -AllowTeamsConsumerInbound $false
```

#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [Microsoft Teams Admin Center](https://admin.teams.microsoft.com).
* [Manage external meetings and chat with people and organizations using Microsoft identities](https://learn.microsoft.com/en-us/microsoftteams/trusted-organizations-external-meetings-chat?tabs=organization-settings)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 378 - 384](https://www.cisecurity.org/benchmark/microsoft_365)
* [CISA MS.TEAMS.2.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/teams.md#msteams22v1)
* [DarkGate malware delivered via Microsoft Teams - detection and response](https://levelblue.com/blogs/security-essentials/darkgate-malware-delivered-via-microsoft-teams-detection-and-response)
* [Midnight Blizzard conducts targeted social engineering over Microsoft Teams](https://www.microsoft.com/en-us/security/blog/2023/08/02/midnight-blizzard-conducts-targeted-social-engineering-over-microsoft-teams/)
* [GIFShell Attack Lets Hackers Create Reverse Shell through Microsoft Teams GIFs](https://www.bitdefender.com/en-us/blog/hotforsecurity/gifshell-attack-lets-hackers-create-reverse-shell-through-microsoft-teams-gifs)

<!--- Results --->
%TestResult%