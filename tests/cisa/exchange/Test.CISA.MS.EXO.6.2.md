Calendar details SHALL NOT be shared with all domains.

Rationale: Calendar details may contain information that should not be shared by default with all domains. Disabling sharing with all domains closes an avenue for data exfiltration while still allowing for legitimate use as needed.

#### Remediation action:

To restrict sharing with all domains:
1. Sign in to the **Exchange admin center**.
2. On the left-hand pane under **Organization**, select **Sharing**.
3. Select [**Individual Sharing**](https://admin.exchange.microsoft.com/#/individualsharing).
4. For all existing policies, select the policy, then select **Manage domains**.
5. For all sharing rules under all existing policies, ensure **Sharing with everyone** and **Anonymous** do not include CalendarSharing.

#### Related links

* [Exchange admin center - Individual Sharing](https://admin.exchange.microsoft.com/#/individualsharing)
* [Microsoft 365 admin center - Org settings - Calendar](https://admin.microsoft.com/#/Settings/Services/:/Settings/L1/Calendar)
* [CISA 6 Calendar and Contact Sharing - MS.EXO.6.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo62v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/EXOConfig.rego#L368)

<!--- Results --->
%TestResult%