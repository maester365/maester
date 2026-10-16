Trial Teams tenants are short-lived organizations that are easy to create and often used for spam and phishing. If your organization can communicate with accounts in trial tenants, users can receive messages and meeting invitations from senders that have little accountability.

Blocking trial tenants keeps communication limited to organizations with a paid or verified tenant. Users in your organization can still communicate with all other allowed external organizations.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Users** > **External access**.
3. Under **Accounts in trial Teams tenants**, select **Block**.
4. Select **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command:

```powershell
Set-CsTenantFederationConfiguration -ExternalAccessWithTrialTenants Blocked
```

#### Related links

* [Microsoft Teams admin center](https://admin.teams.microsoft.com)
* [Manage external meetings and chat with people and organizations](https://learn.microsoft.com/microsoftteams/manage-external-access)
* [Set-CsTenantFederationConfiguration](https://learn.microsoft.com/powershell/module/teams/set-cstenantfederationconfiguration)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.2.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
