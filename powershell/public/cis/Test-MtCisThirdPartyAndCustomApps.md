8.4.1 (L1) Ensure app permission policies are configured

This policy setting controls which class of apps are available for users to install.

#### Rationale

Allowing users to install third-party or unverified apps poses a potential risk of introducing malicious software to the environment.

#### Impact

Users will only be able to install approved classes of apps.

#### Remediation action

1. Navigate to [Microsoft Teams Admin Center](https://admin.teams.microsoft.com).
2. Click to expand **Teams apps** select **Permission policies**.
3. Select the **Global (Org-wide default)** policy.
4. Under **Third-party apps**, set to **Block all apps** (or **Allow specific apps and block all others**).
5. Under **Custom apps**, set to **Block all apps** (or **Allow specific apps and block all others**).
6. Click **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following command to block all third-party and custom apps:

```powershell
Set-CsTeamsAppPermissionPolicy -Identity Global -GlobalCatalogAppsType BlockedAppList -PrivateCatalogAppsType BlockedAppList
```

#### Related links

* [Microsoft Teams Admin Center](https://admin.teams.microsoft.com).
* [Manage app permission policies in Microsoft Teams](https://learn.microsoft.com/microsoftteams/teams-app-permission-policies)
* [Set-CsTeamsAppPermissionPolicy](https://learn.microsoft.com/powershell/module/teams/set-csteamsapppermissionpolicy)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - Page 526](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
