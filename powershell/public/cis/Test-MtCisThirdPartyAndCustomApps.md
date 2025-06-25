8.4.1 (L1) Ensure app permission policies are configured

This test checks if the usage of third-party and custom apps are disabled.

This policy setting controls which class of apps are available for users to install.

Rationale:\
Allowing users to install third-party or unverified apps poses a potential risk of  introducing malicious software to the environment.

#### Remediation action:

> **NOTE:** Previously, this could be managed from the Permission policies under Teams apps in the Teams admin portal. The Permission policies now redirects you to the Manage Apps page. You can manage apps there now using the `Org-wide app settings` under _Actions_, but it's easier to remediate the recommended settings using PowerShell.

##### PowerShell

To change app permission policies using PowerShell

```powershell
# This cmdlet requires the MicrosoftTeams PowerShell module
# Make sure you're connected to Microsoft Teams using the Connect-MicrosoftTeams cmdlet before executing

## Enable all Microsoft Apps and Disable Third-party and Custom Apps
Set-CsTeamsAppPermissionPolicy -Identity Global -DefaultCatalogAppsType BlockedAppList -DefaultCatalogApps @() -GlobalCatalogAppsType AllowedAppList -GlobalCatalogApps @() -PrivateCatalogAppsType AllowedAppList -PrivateCatalogApps @()
```

##### Microsoft Teams Admin Center

To change app permission policies using the UI:
1. Navigate to **Microsoft Teams admin center** [https://admin.teams.microsoft.com](https://admin.teams.microsoft.com).
2. Click to expand **Teams Apps** [Teams apps | Teams admin center](https://admin.teams.microsoft.com/policies/manage-apps)
3. Under **Actions**, select **Org-wide app settings**
4. For **Microsoft apps** set **Let users install and use available apps by default** to **On** or less permissive.
5. For **Third-party apps** set **Let users install and use available apps by default** to **Off**.
6. For **Custom apps** set **Let users install and use available apps by default** to **Off**.
7. For **Custom apps** set **Let users interact with custom apps in preview** to **Off**.
8. Click **Save**.

#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [Microsoft Teams Admin Center](https://admin.teams.microsoft.com).
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 391](https://www.cisecurity.org/benchmark/microsoft_365)
* [CISA MS.TEAMS.5.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/teams.md#msteams52v1)
* [CISA MS.TEAMS.5.3v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/teams.md#msteams53v1)

<!--- Results --->
%TestResult%