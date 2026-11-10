The DLP policy SHOULD block access to sensitive information by restricted applications and unwanted Bluetooth applications.

This is a manual baseline requirement and ScubaGear does not automate it. It applies only when at least one device is onboarded to Defender for Endpoint; verify whether the requirement applies before assessing the configuration.

#### Remediation action

1. Sign in to the [Microsoft Purview portal](https://purview.microsoft.com/datalossprevention/policies).
2. Confirm whether at least one device is onboarded to Defender for Endpoint. If none are onboarded, record the requirement as not applicable for the tenant.
3. If applicable, verify that endpoint DLP blocks access to sensitive information by restricted applications and blocks **Copy or move using unallowed Bluetooth app**.
4. Document the assessment and any approved third-party control used to meet the requirement.

#### Related links

* [Get started with Endpoint data loss prevention](https://learn.microsoft.com/purview/endpoint-dlp-getting-started)
* [CISA Security Suite baseline - MS.SECURITYSUITE.3.5v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite35v1)

<!--- Results --->
%TestResult%
