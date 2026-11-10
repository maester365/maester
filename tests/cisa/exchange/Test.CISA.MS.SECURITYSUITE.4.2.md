The alerts SHOULD be sent to a monitored address or incorporated into a Security Information and Event Management (SIEM).

Rationale: Suspicious or malicious events, if not resolved promptly, may have a greater impact to users and the agency. Sending alerts to a monitored email address or SIEM system helps ensure these suspicious or malicious events are acted upon in a timely manner to limit overall impact.

#### Remediation action:

1. Sign in to **Microsoft 365 Defender**.
2. Select [**Settings**](https://security.microsoft.com/securitysettings).
3. Select either:
    - [**Microsoft Sentinel**](https://security.microsoft.com/sentinel/settings).
    - **Defender XDR**, and under **General**, select [**Streaming API**](https://security.microsoft.com/securitysettings/defender/raw_data_export).
4. Ensure a SIEM integration is configured for your organization.

#### Related links

* [Defender admin center - Alert policy](https://security.microsoft.com/alertpoliciesv2)
* [Defender admin center - Streaming API](https://security.microsoft.com/securitysettings/defender/raw_data_export)
* [Defender admin center - Sentinel workspaces](https://security.microsoft.com/sentinel/settings)
* [CISA Security Suite baseline - MS.SECURITYSUITE.4.2v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite42v1)
* [CISA ScubaGear Security Suite implementation](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/Rego/SecuritySuiteConfig.rego)

<!--- Results --->
%TestResult%