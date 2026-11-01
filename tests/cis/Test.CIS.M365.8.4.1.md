Users can't install third-party or custom Teams apps by default, and can't interact with custom apps in preview.

Third-party and custom apps can read and act on Teams data on behalf of users. An app that a user adds without review may be malicious, unverified or over-privileged, and custom apps in preview can be uploaded without admin approval. Turning these defaults off means that only apps an admin has made available can be used. Admins can still make individual apps available to everyone or to specific users and groups on the **Manage apps** page; the org-wide settings apply to apps whose availability hasn't been set.

The test reads the org-wide app settings with `Get-M365UnifiedTenantSettings` (`GlobalApp` for third-party apps and `PrivateApp` for custom apps must be `None`) and `Get-CsTeamsSettingsCustomApp` (`IsSideloadedAppsInteractionEnabled` must be `False`). Microsoft doesn't support `Get-M365UnifiedTenantSettings` with application-based Teams authentication, and the documented Graph teams-app-settings endpoint doesn't support application permissions for these settings. The test skips app-only contexts; run it with delegated authentication.

#### Remediation action

1. Sign in to the [Microsoft Teams admin center](https://admin.teams.microsoft.com).
2. Go to **Teams apps** > [**Manage apps**](https://admin.teams.microsoft.com/policies/manage-apps).
3. Select **Actions** > **Org-wide app settings**.
4. Under **Third-party apps**, turn off **Let users install and use available apps by default**.
5. Under **Custom apps**, turn off **Let users install and use available apps by default**.
6. Under **Custom apps**, turn off **Let users interact with custom apps in preview**.
7. Select **Save**.

##### PowerShell

1. Connect to Teams PowerShell using `Connect-MicrosoftTeams`.
2. Run the following commands:

```powershell
Update-M365UnifiedTenantSettings -SettingName GlobalApp -SettingValue None
Update-M365UnifiedTenantSettings -SettingName PrivateApp -SettingValue None
Set-CsTeamsSettingsCustomApp -isSideloadedAppsInteractionEnabled $false
```

#### Related links

* [Microsoft Teams admin center - Manage apps](https://admin.teams.microsoft.com/policies/manage-apps)
* [App centric management to manage user access to Teams apps](https://learn.microsoft.com/microsoftteams/app-centric-management)
* [Manage custom app policies and settings](https://learn.microsoft.com/microsoftteams/teams-custom-app-policies-and-settings)
* [Update-M365UnifiedTenantSettings](https://learn.microsoft.com/powershell/module/microsoftteams/update-m365unifiedtenantsettings)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 8.4.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
