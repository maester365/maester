8.4.1 (L1) Ensure app permission policies are configured

This test checks if the usage of third-party and custom apps are disabled.

This policy setting controls which class of apps are available for users to install.

Rationale:\
Allowing users to install third-party or unverified apps poses a potential risk of  introducing malicious software to the environment.

#### Remediation action:

##### Microsoft Teams Admin Center

To change app permission policies using the UI:
1. Navigate to **Microsoft Teams admin center** [https://admin.teams.microsoft.com](https://admin.teams.microsoft.com).
2. Click to expand **Teams apps** select **Permission policies**.
3. Select **Global (Org-wide default)** policy.
4. For **Microsoft apps** set **Let users install and use available apps by default** to **On** or less permissive.
5. For **Third-party apps** set **Let users install and use available apps by default** to **Off**.
6. For **Custom apps** set **Let users install and use available apps by default** to **Off**.

Make sure to also check the Org-wide app settings:
1. Navigate to **Microsoft Teams admin center** [https://admin.teams.microsoft.com](https://admin.teams.microsoft.com).
2. Click to expand **Teams apps** select **Manage apps**.
3. In the upper right click **Actions** > **Org-wide app settings**.
4. For **Third-party apps** set **Third-party apps** and **New third-party apps published to the store** to **Off**.
5. For **Custom apps** set **Let users interact with custom apps in preview** to **Off**.
6. Click **Save**.

##### PowerShell

To change app permission policies using PowerShell

```powershell
# This cmdlet requires the MicrosoftTeams PowerShell module
# Make sure you're connected to Microsoft Teams using the Connect-MicrosoftTeams cmdlet before executing

## Enable all Microsoft Apps and Disable Third-party and Custom Apps
Set-CsTeamsAppPermissionPolicy -Identity Global -DefaultCatalogAppsType BlockedAppList -DefaultCatalogApps @() -GlobalCatalogAppsType AllowedAppList -GlobalCatalogApps @() -PrivateCatalogAppsType AllowedAppList -PrivateCatalogApps @()
```

#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [Microsoft Teams Admin Center](https://admin.teams.microsoft.com).
* [CIS Microsoft 365 Foundations Benchmark v4.0.0 - Page 359](https://www.cisecurity.org/benchmark/microsoft_365)
* [CISA MS.TEAMS.5.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/teams.md#msteams52v1)
* [CISA MS.TEAMS.5.3v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/teams.md#msteams53v1)

<!--- Results --->
%TestResult%