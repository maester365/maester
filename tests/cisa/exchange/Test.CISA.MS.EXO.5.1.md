SMTP AUTH SHALL be disabled.

Rationale: SMTP AUTH is not used or needed by modern email clients. Therefore, disabling it as the global default conforms to the principle of least functionality.

#### Remediation action:

1. To disable SMTP AUTH for the organization:
2. Sign in to the **Exchange admin center**.
3. On the left hand pane, select [**Settings**](https://admin.exchange.microsoft.com/#/settings); then from the settings list, select **Mail Flow**.
4. Make sure the setting **Turn off SMTP AUTH protocol for your organization** is checked.

#### Related links

* [Exchange admin center - Settings](https://admin.exchange.microsoft.com/#/settings)
* [CISA 5 Simple Mail Transfer Protocol Authentication - MS.EXO.5.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo51v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/EXOConfig.rego#L306)

<!--- Results --->
%TestResult%