Federation lets users in other Microsoft 365 and Teams organizations find and message people in your tenant. If every known external domain is allowed, anyone with a tenant in those domains can start chats with your users. That is a common route for phishing and social engineering, because the sender looks like a normal business contact.

Restricting external domains means only the partner domains you choose can communicate with your users. Turning federation off removes the path completely.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Users** > **External access**.
3. Next to **Teams and Skype for Business users in external organizations**, choose **Allow only specific external domains**, select **Add external domains** and add the approved domains. To turn external access off instead, choose **Block all external domains**.
4. Select **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following commands to allow only specific domains, replacing the example domain with your approved domains. The list replaces the domains that are allowed now:

```powershell
$domains = [System.Collections.Generic.List[string]]::new()
$domains.Add('partner.example.com')
Set-CsTenantFederationConfiguration -AllowFederatedUsers $true -AllowedDomainsAsAList $domains
```

>Note: Setting AllowFederatedUsers to $false also meets the recommended state.

#### Related links

* [Microsoft Teams admin center](https://admin.teams.microsoft.com)
* [Manage external meetings and chat with people and organizations](https://learn.microsoft.com/microsoftteams/manage-external-access)
* [Set-CsTenantFederationConfiguration](https://learn.microsoft.com/powershell/module/teams/set-cstenantfederationconfiguration)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.2.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
