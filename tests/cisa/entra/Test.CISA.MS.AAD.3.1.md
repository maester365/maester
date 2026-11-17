Phishing-resistant MFA SHALL be enforced for all users.

Rationale: Weaker forms of MFA do not protect against sophisticated phishing attacks. By enforcing methods resistant to phishing, those risks are minimized.

The test passes when an enabled Conditional Access policy for all users and all cloud apps requires the built-in **Phishing-resistant MFA** authentication strength, or a custom authentication strength limited to Windows Hello for Business, passkeys (FIDO2) and certificate-based multifactor authentication. User and group exclusions are accepted only when they match an emergency access account or group listed in `GlobalSettings.EmergencyAccessAccounts` in `maester-config.json`; add excluded emergency access principals there for the policy to count. See [Emergency access accounts](https://maester.dev/docs/configuration/emergency-access-accounts).

Policies with other user or group exclusions, or any role, application, or guest exclusions, are not counted. The SCuBA baseline identifies this requirement as supporting capped exclusions (`CapExclusions`); Maester uses its configured emergency access accounts and groups for that limited exception.

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
