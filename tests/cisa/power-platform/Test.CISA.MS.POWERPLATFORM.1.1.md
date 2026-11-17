Checks that only administrators can create production and sandbox Power Platform environments (`disableEnvironmentCreationByNonAdminUsers` is `true`).

Unrestricted environment creation lets any licensed user create environments outside the controls administrators apply to managed environments, such as data policies and monitoring. Those environments can be used to move organizational data to external services.

#### Remediation action

1. Sign in to the [Power Platform admin center](https://admin.powerplatform.microsoft.com).
2. Select **Settings** and then **Power Platform settings**.
3. Under **Production and Sandbox environment assignments**, select **Only specific admins**.
4. Select **Save**.

#### Related links

- [CISA SCuBA Power Platform baseline MS.POWERPLATFORM.1.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerplatform.md#mspowerplatform1)
- [Control who can create and manage environments](https://learn.microsoft.com/power-platform/admin/control-environment-creation)

<!--- Results --->
%TestResult%
