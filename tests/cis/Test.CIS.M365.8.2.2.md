Users can't chat or meet with external users who have unmanaged Microsoft accounts, such as Microsoft Teams (free).

Little effort is needed to get a free or trial Teams account, so attackers use unmanaged accounts to reach users through external access. Attacks delivered this way include DarkGate malware, social engineering and phishing by Midnight Blizzard, GIFShell and username enumeration. Turning off communication with unmanaged accounts removes that channel. Users can no longer communicate with Teams users who aren't managed by an organization; create a separate policy for groups that need to. This setting doesn't control anonymous meeting join through a shared link, and isn't available in GCC, GCC High, DoD or private cloud environments.

The test passes when the Global (Org-wide default) external access policy or the organization settings turn the setting off.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **External collaboration** > **External access** and open the **Policies** tab.
3. Select the **Global (Org-wide default)** policy.
4. Set **People in my org can chat and have meetings with external users who have unmanaged Microsoft accounts** to **Off**.
5. Select **Save**.

Turning the same setting **Off** on the **Organization settings** tab also meets the recommendation.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command:

```powershell
Set-CsExternalAccessPolicy -Identity Global -EnableTeamsConsumerAccess $false
```

#### Related links

* [Microsoft Teams admin center](https://admin.teams.microsoft.com)
* [Manage external meetings and chat with people and organizations using Microsoft identities](https://learn.microsoft.com/microsoftteams/trusted-organizations-external-meetings-chat)
* [Midnight Blizzard conducts targeted social engineering over Microsoft Teams](https://www.microsoft.com/security/blog/2023/08/02/midnight-blizzard-conducts-targeted-social-engineering-over-microsoft-teams/)
* [GIFShell Attack Lets Hackers Create Reverse Shell through Microsoft Teams GIFs](https://www.bitdefender.com/en-us/blog/hotforsecurity/gifshell-attack-lets-hackers-create-reverse-shell-through-microsoft-teams-gifs)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.2.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
