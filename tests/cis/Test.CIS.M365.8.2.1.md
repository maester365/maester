Federation lets users in other Microsoft 365 and Teams organizations find and message people in your tenant. If every known external domain is allowed, anyone with a tenant in those domains can start chats with your users. That is a common route for phishing and social engineering, because the sender looks like a normal business contact.

Turning off external domains in the Global (Org-wide default) external access policy removes that path for everyone the policy applies to. Users who need to work with external organizations can be given a custom external access policy, or the organization settings can allow only specific partner domains. The test passes when the Global policy turns off external domains, or when the organization settings turn external domains off, block all of them or allow only specific domains.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **External collaboration** > **External access** and open the **Policies** tab.
3. Select the **Global (Org-wide default)** policy.
4. Set **Manage external domains for this policy** to **Off**.
5. Select **Save**.

On the **Organization settings** tab, setting **Manage external domains for this organization** to **Off**, or to **On** with **Allow only specific external domains** or **Block all external domains**, also meets the recommendation.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command:

```powershell
Set-CsExternalAccessPolicy -Identity Global -EnableFederationAccess $false
```

To allow only specific domains for the organization instead, run the following commands, replacing the example domain with your approved domains. The list replaces the domains that are allowed now:

```powershell
$domains = [System.Collections.Generic.List[string]]::new()
$domains.Add('partner.example.com')
Set-CsTenantFederationConfiguration -AllowFederatedUsers $true -AllowedDomainsAsAList $domains
```

#### Related links

* [Microsoft Teams admin center](https://admin.teams.microsoft.com)
* [Manage external meetings and chat with people and organizations](https://learn.microsoft.com/microsoftteams/manage-external-access)
* [Set-CsExternalAccessPolicy](https://learn.microsoft.com/powershell/module/microsoftteams/set-csexternalaccesspolicy)
* [Set-CsTenantFederationConfiguration](https://learn.microsoft.com/powershell/module/teams/set-cstenantfederationconfiguration)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.2.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
