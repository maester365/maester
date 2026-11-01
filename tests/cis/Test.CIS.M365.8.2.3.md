External users with unmanaged Microsoft accounts, such as Microsoft Teams (free), can't start chats or meetings with users in your organization.

Little effort is needed to get a free or trial Teams account, so attackers use unmanaged accounts to contact users through external access. Attacks delivered this way include DarkGate malware, social engineering and phishing by Midnight Blizzard, GIFShell and username enumeration. This setting is a stop gap for CIS 8.2.2: if some users are allowed to communicate with unmanaged accounts, they still can't be contacted first. Turning off the parent setting in 8.2.2 also blocks inbound contact. Users with an exception can still join meetings that unmanaged users set up, depending on the parent setting. This setting isn't available in GCC, GCC High, DoD or private cloud environments.

The test passes when the Global (Org-wide default) external access policy or the organization settings turn off inbound contact from unmanaged accounts.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **External collaboration** > **External access** and open the **Policies** tab.
3. Select the **Global (Org-wide default)** policy.
4. Under **People in my org can chat and have meetings with external users who have unmanaged Microsoft accounts**, clear **People in my org can join external meetings and receive new chats from users who have unmanaged Microsoft accounts**.
5. Select **Save**.

If the parent setting is already **Off**, the option isn't shown and the recommendation is met. Clearing the same option on the **Organization settings** tab also meets the recommendation.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command:

```powershell
Set-CsExternalAccessPolicy -Identity Global -EnableTeamsConsumerInbound $false
```

#### Related links

* [Microsoft Teams admin center](https://admin.teams.microsoft.com)
* [Manage external meetings and chat with people and organizations using Microsoft identities](https://learn.microsoft.com/microsoftteams/trusted-organizations-external-meetings-chat)
* [Midnight Blizzard conducts targeted social engineering over Microsoft Teams](https://www.microsoft.com/security/blog/2023/08/02/midnight-blizzard-conducts-targeted-social-engineering-over-microsoft-teams/)
* [GIFShell Attack Lets Hackers Create Reverse Shell through Microsoft Teams GIFs](https://www.bitdefender.com/en-us/blog/hotforsecurity/gifshell-attack-lets-hackers-create-reverse-shell-through-microsoft-teams-gifs)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.2.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
