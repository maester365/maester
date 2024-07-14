A notification SHOULD be sent to the administrator when high-risk users are detected.

Rationale: Notification enables the admin to monitor the event and remediate the risk. This helps the organization proactively respond to cyber intrusions as they occur.

#### Remediation action:

Follow the guide below to configure Entra ID Protection to send a regularly monitored security mailbox email notification when user accounts are determined to be high risk.

- [Configure Entra Identity Protection Notifications - Microsoft Learn](https://learn.microsoft.com/entra/id-protection/howto-identity-protection-configure-notifications#configure-users-at-risk-detected-alerts)

#### Related links

- [CISA Risk Based Policies - MS.AAD.2.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad22v1)
- [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L122)

<!--- Results --->
%TestResult%
