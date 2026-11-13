User warnings, comparable to the user safety tips included with EOP, SHOULD be displayed for all recipients.

Rationale: Many tasks are better suited for automated processes, such as identifying unusual characters in the `FROM` address or identifying a first-time sender. User warnings can handle these tasks, reducing the burden on end users and the risk of successful phishing attempts.

#### Remediation action

1. Sign in to the [Microsoft Defender anti-phishing policies page](https://security.microsoft.com/antiphishing).
2. Enable first-contact, similar-user, similar-domain, unusual-character, via-tag, and unauthenticated-sender safety tips in an enabled custom anti-phishing policy that applies to all recipients; or enable an all-recipient Standard or Strict preset policy.

#### Related links

* [Defender admin center - Preset security policies](https://security.microsoft.com/presetSecurityPolicies)
* [CISA Security Suite baseline - MS.SECURITYSUITE.2.4v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite24v1)
* [CISA ScubaGear Security Suite implementation](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/Rego/SecuritySuiteConfig.rego)
* [Microsoft Learn - Impersonation settings in anti-phishing policies in Microsoft Defender for Office 365](https://learn.microsoft.com/defender-office-365/anti-phishing-policies-about#impersonation-settings-in-anti-phishing-policies-in-microsoft-defender-for-office-365)

<!--- Results --->
%TestResult%
