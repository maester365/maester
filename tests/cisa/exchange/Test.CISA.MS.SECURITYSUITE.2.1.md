User impersonation protection SHOULD be enabled for all sensitive accounts that the agency configures.

Rationale: Users might not be able to reliably identify phishing emails, especially if the `FROM` address is nearly indistinguishable from that of a known entity. By automatically identifying senders who appear to be impersonating known senders, the risk of a successful phishing attempt can be reduced. The check compares the configured sensitive-user list with the users protected by an enabled, all-recipient anti-phishing policy.

#### Remediation action

1. Set the test's `SensitiveUsers` parameter to the agency's sensitive account email addresses. An entry may also be written as `Display Name;email@agency.gov`.
2. Sign in to the [Microsoft Defender anti-phishing policies page](https://security.microsoft.com/antiphishing).
3. In an enabled anti-phishing policy that applies to all recipients, enable **User impersonation protection** and add every configured account under **Users to protect**.
4. Choose an action other than **No action** or **Bcc message**, then save the policy.

An empty `SensitiveUsers` list is not treated as evidence of compliance.

#### Related links

* [Defender admin center - Preset security policies](https://security.microsoft.com/presetSecurityPolicies)
* [CISA Security Suite baseline - MS.SECURITYSUITE.2.1v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite21v1)
* [CISA ScubaGear Security Suite implementation](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/Rego/SecuritySuiteConfig.rego)
* [Microsoft Learn - Impersonation settings in anti-phishing policies in Microsoft Defender for Office 365](https://learn.microsoft.com/defender-office-365/anti-phishing-policies-about#impersonation-settings-in-anti-phishing-policies-in-microsoft-defender-for-office-365)

<!--- Results --->
%TestResult%
