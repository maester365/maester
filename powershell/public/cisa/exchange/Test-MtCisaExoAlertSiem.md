Alerts SHOULD be sent to a monitored address or incorporated into a security information and event management (SIEM) system.

Rationale: Suspicious or malicious events, if not resolved promptly, may have a greater impact to users and the agency. Sending alerts to a monitored email address or SIEM system helps ensure these suspicious or malicious events are acted upon in a timely manner to limit overall impact.

#### Remediation action:

1. Sign in to **Microsoft 365 Defender**.
2. Select [**Settings**](https://security.microsoft.com/securitysettings).
3. Select either:
    a. [**Microsoft Sentinel**](https://security.microsoft.com/sentinel/settings).
    b. **Defender XDR**, and under **General**, select [**Streaming API**](https://security.microsoft.com/securitysettings/defender/raw_data_export).
4. Ensure a SIEM integration is configured for your organization.

#### Related links

* [Defender admin center - Alert policy](https://security.microsoft.com/alertpoliciesv2)
* [Defender admin center - Streaming API](https://security.microsoft.com/securitysettings/defender/raw_data_export)
* [Defender admin center - Sentinel workspaces](https://security.microsoft.com/sentinel/settings)
* [CISA 16 Alerts - MS.EXO.16.2](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo162v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/EXOConfig.rego#L878)

<!--- Results --->
%TestResult%