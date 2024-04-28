Managed Devices SHOULD be required to register MFA.

Rationale: Reduce risk of an adversary using stolen user credentials and then registering their own MFA device to access the tenant by requiring a managed device provisioned and controlled by the agency to perform registration actions. This prevents the adversary from using their own unmanaged device to perform the registration.

#### Remediation action:

Create a conditional access policy requiring a user to be on a managed device when registering for MFA. Configure the following policy settings in the new conditional access policy, per the values below:

* Users > Include > **All users**
* Target resources > User actions > **Register security information**
* Access controls > Grant > Grant Access > **Require device to be marked as compliant** and **Require Microsoft Entra hybrid joined device** > For multiple controls > **Require one of the selected controls**

#### Related links

* [CISA Strong Authentication & Secure Registration - MS.AAD.3.8v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad38v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L431)

<!--- Results --->
%TestResult%
