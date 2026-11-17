Checks that only administrators can create Power Pages sites (`disablePortalsCreationByNonAdminUsers` is `true`).

Power Pages sites can be exposed to anonymous internet users. Letting any user create one risks unintended public exposure of organizational data.

#### Remediation action

1. Connect with `Add-PowerAppsAccount -Endpoint prod` (use `-Endpoint usgov` for GCC or `-Endpoint usgovhigh` for GCC High).
2. Run:

   ```powershell
   Set-TenantSettings -RequestBody @{ "disablePortalsCreationByNonAdminUsers" = $true }
   ```

#### Related links

- [CISA SCuBA Power Platform baseline MS.POWERPLATFORM.5.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerplatform.md#mspowerplatform5)
- [Power Pages security](https://learn.microsoft.com/power-pages/security/power-pages-security)

<!--- Results --->
%TestResult%
