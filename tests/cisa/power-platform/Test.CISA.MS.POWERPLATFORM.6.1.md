Checks that the Power Apps "Share with everyone" feature is disabled (`powerPlatform.powerApps.disableShareWithEveryone` is `true`).

Sharing an app with everyone gives every user in the organization access to it, which can expose data or functionality beyond the intended audience.

#### Remediation action

1. Connect with `Add-PowerAppsAccount -Endpoint prod` (use `-Endpoint usgov` for GCC High).
2. Run:

   ```powershell
   $tenantSettings = Get-TenantSettings
   $tenantSettings.powerPlatform.powerApps.disableShareWithEveryone = $true
   Set-TenantSettings -RequestBody $tenantSettings
   ```

#### Related links

- [CISA SCuBA Power Platform baseline MS.POWERPLATFORM.6.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerplatform.md#mspowerplatform6)
- [Share a canvas app with security groups](https://learn.microsoft.com/power-apps/maker/canvas-apps/share-app)

<!--- Results --->
%TestResult%
