8.2.3 (L1) Ensure external Teams users cannot initiate conversations

This setting prevents external users who are not managed by an organization from initiating contact with users in the protected organization. The recommended state is to uncheck **External users with Teams accounts not managed by an organization can contact users in my organization**.

>Note: Disabling this setting is used as an additional stop gap for the previous setting which disables communication with unmanaged Teams users entirely. If an organization chooses to have an exception to (L1) Ensure communication with unmanaged Teams users is disabled they can do so while also disabling the ability for the same group of users to initiate contact. Disabling communication entirely will also disable the ability for unmanaged users to initiate contact.

#### Rationale

Allowing users to communicate with unmanaged Teams users presents a potential security threat as little effort is required by threat actors to gain access to a trial or free Microsoft Teams account.

Some real-world attacks and exploits delivered via Teams over external access channels include:
* DarkGate malware
* Social engineering / Phishing attacks by "Midnight Blizzard"
* GIFShell
* Username enumeration

#### Impact

The impact of disabling this is very low.
Organizations may choose to create additional policies for specific groups that need to communicate with unmanaged external users.

>Note: Chats and meetings with external unmanaged Teams users isn't available in GCC, GCC High, or DOD deployments, or in private cloud environments.

#### Remediation action:

To remediate using the UI:
1. Navigate to [Microsoft 365 Teams Admin Center](https://admin.teams.microsoft.com).
2. Click to expand **Users** select **External access**.
3. Select the **Policies** tab
4. Click on the **Global (Org-wide default)** policy.
5. Locate the parent setting **People in my organization can communicate with unmanaged Teams accounts**.
6. Uncheck **External users with Teams accounts not managed by an organization can contact users in my organization**.
7. Click **Save**.

>Note: If People in my organization can communicate with unmanaged Teams accounts is already set to Off then this setting will not be visible and will satisfy the requirements of this recommendation.


##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command:
```powershell
Set-CsExternalAccessPolicy -Identity Global -EnableTeamsConsumerInbound $false
```

>Note: Configuring the organization settings to block inbound communication is also in compliance with this control.


#### Related links

* [Microsoft 365 Teams Admin Center](https://admin.teams.microsoft.com)
* [IT Admins - Manage external meetings and chat with people and organizations using Microsoft identities](https://learn.microsoft.com/en-us/microsoftteams/trusted-organizations-external-meetings-chat?tabs=organization-settings)
* [Midnight Blizzard conducts targeted social engineering over Microsoft Teams](https://www.microsoft.com/en-us/security/blog/2023/08/02/midnight-blizzard-conducts-targeted-social-engineering-over-microsoft-teams/)
* [GIFShell Attack Lets Hackers Create Reverse Shell through Microsoft Teams GIFs](https://www.bitdefender.com/en-us/blog/hotforsecurity/gifshell-attack-lets-hackers-create-reverse-shell-through-microsoft-teams-gifs)
* [CIS Microsoft 365 Foundations Benchmark v6.0.1 - Page 416](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%