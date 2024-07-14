Sign-ins detected as high risk SHALL be blocked.

Rationale: Blocking high-risk sign ins may prevent compromised sign-ins from accessing the tenant. This prevents compromised sign-ins from accessing the tenant.

#### Remediation action:

Create a Conditional Access policy blocking sign-ins determined high risk by the Identity Protection service. Configure the following policy settings in the new Conditional Access policy as per the values below:

* Users > Include > **All users**
* Target resources > Cloud apps > **All cloud apps**
* Conditions > Sign-in risk > **High**
* Access controls > Grant > **Block Access**

Note: While CISA recommends blocking, the [Microsoft recommendation](https://learn.microsoft.com/entra/id-protection/howto-identity-protection-configure-risk-policies#microsofts-recommendation) is to require multi-factor authentication for high-risk sign-ins.

#### Related links

* [CISA Risk Based Policies - MS.AAD.2.3](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad23v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L138)

<!--- Results --->
%TestResult%
