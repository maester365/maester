Managed devices SHOULD be required for authentication.

Rationale: The security risk of an adversary authenticating to the tenant from their own device is reduced by requiring a managed device to authenticate. Managed devices are under the provisioning and control of the agency. [OMB-22-09](https://www.whitehouse.gov/wp-content/uploads/2022/01/M-22-09.pdf) states, "When authorizing users to access resources, agencies must consider at least one device-level signal alongside identity information about the authenticated user."

#### Remediation action:

Create a conditional access policy requiring a user's device to be either Microsoft Entra hybrid joined or compliant during authentication. Configure the following policy settings in the new conditional access policy, per the values below:

1. In **Entra** under **Protection** and **Conditional Access**, select **[Policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies/fromNav/)**.
2. Click on **New policy**
3. Under **New Conditional Access policy**, configure the following policy settings in the new conditional access policy, per the values below:
    * Users > Include > **All users**
    * Target resources > Cloud apps > **All cloud apps**
    * Access controls > Grant > Grant Access > **Require device to be marked as compliant** and **Require Microsoft Entra hybrid joined device** > For multiple controls > **Require one of the selected controls**
4. Click **Save**.

#### Related links

* [Entra admin center - Conditional Access | Policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies/fromNav/)
* [CISA Strong Authentication & Secure Registration - MS.AAD.3.7v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad37v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L397)

<!--- Results --->
%TestResult%
