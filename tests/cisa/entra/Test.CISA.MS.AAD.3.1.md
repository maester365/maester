Phishing-resistant MFA SHALL be enforced for all users.

Rationale: Weaker forms of MFA do not protect against sophisticated phishing attacks. By enforcing methods resistant to phishing, those risks are minimized.

The test passes when an enabled Conditional Access policy includes all users and all cloud apps and specifies the built-in **Phishing-resistant MFA** authentication strength, or a custom authentication strength limited to Windows Hello for Business, passkeys (FIDO2) and certificate-based multifactor authentication. It does not assess exclusions, narrowing conditions or alternative grant controls, so a pass alone does not establish coverage for every sign-in. Review those policy settings separately.

#### Remediation action:

Create a Conditional Access policy enforcing phishing-resistant MFA for all users. Configure the following policy settings in the new Conditional Access policy, per the values below:

* Users > Include > **All users**
* Target resources > Cloud apps > **All cloud apps**
* Access controls > Grant > Grant Access > Require authentication strength > **Phishing-resistant MFA**

#### Related links

* [CISA Strong Authentication & Secure Registration - MS.AAD.3.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad31v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L181)

<!--- Results --->
%TestResult%
