Trial Teams tenants are tenants that have only trial licenses and no purchased licenses. They are short-lived, easy to create and often used for spam and phishing. If your organization can communicate with accounts in trial tenants, users can receive messages and meeting invitations from senders that have little accountability.

Blocking trial tenants keeps external communication limited to organizations that have purchased licenses. Users in your organization can still communicate with all other allowed external organizations. Users from trial tenants are removed from existing chats, so contacts who use a trial tenant need another channel, such as email, until they move to a licensed tenant.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **External collaboration** > **External access** and open the **Organization settings** tab.
3. Set **People in my organization can communicate with accounts in trial Teams tenants** to **Off**.
4. Select **Save**.

Off (`Blocked`) is the default value, so a tenant fails this test only when the setting has been changed.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command:

```powershell
Set-CsTenantFederationConfiguration -ExternalAccessWithTrialTenants Blocked
```

#### Related links

* [Manage external meetings and chat with people and organizations](https://learn.microsoft.com/microsoftteams/manage-external-access)
* [Set-CsTenantFederationConfiguration](https://learn.microsoft.com/powershell/module/teams/set-cstenantfederationconfiguration)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.2.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
