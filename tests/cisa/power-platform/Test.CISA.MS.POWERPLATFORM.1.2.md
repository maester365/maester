Checks that only administrators can create trial Power Platform environments (`disableTrialEnvironmentCreationByNonAdminUsers` is `true`).

Trial environments created by any user sit outside administrator oversight and can hold organizational data without the controls applied to managed environments.

#### Remediation action

1. Sign in to the [Power Platform admin center](https://admin.powerplatform.microsoft.com).
2. Select **Settings** and then **Power Platform settings**.
3. Under **Trial environment assignments**, select **Only specific admins**.
4. Select **Save**.

#### Related links

- [CISA SCuBA Power Platform baseline MS.POWERPLATFORM.1.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerplatform.md#mspowerplatform1)
- [Control who can create and manage environments](https://learn.microsoft.com/power-platform/admin/control-environment-creation)

<!--- Results --->
%TestResult%
