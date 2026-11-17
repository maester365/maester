Allowed domains SHALL NOT be added to inbound anti-spam protection policies.

Rationale: Legitimate emails may be incorrectly filtered by spam protections. Adding allowed senders is an acceptable method of combating these false positives. Allowing an entire domain, especially a common domain like office.com, however, provides for a large number of potentially unknown users to bypass spam protections.

#### Remediation action

1. Sign in to **Microsoft 365 Defender**.
2. In the left-hand menu, go to **Email & Collaboration** > **Policies & Rules**.
3. Select **Threat Policies**.
4. Review active **Strict**, **Standard**, all-recipient custom, and default anti-spam policies in precedence order.
5. For the effective policy or policies, remove every allowed sender domain. A compliant higher-priority policy shields lower-priority policies; standard and strict presets satisfy the requirement when they are active and compliant.
6. Save any changes.

#### Related links

* [Defender admin center - Preset security policies](https://security.microsoft.com/presetSecurityPolicies)
* [CISA Security Suite baseline - MS.SECURITYSUITE.6.2v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite62v1)
* [CISA ScubaGear Security Suite implementation](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/Rego/SecuritySuiteConfig.rego)

<!--- Results --->
%TestResult%
