A Conditional Access policy should enforce the Global Secure Access **Compliant Network** control - blocking access when the session is not on a compliant network. This provides token replay protection: a stolen token cannot be used from outside the organization's compliant network.

To avoid breaking device onboarding, the policy must exclude the **Microsoft Intune** and **Microsoft Intune Enrollment** applications - devices must be able to enroll before the Global Secure Access client exists on them.

#### Remediation action:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a **Conditional Access Administrator**.
2. Browse to **Entra ID** > **Conditional Access** > **Policies**.
3. Create or edit an enabled policy that targets **All resources**, includes **All** network locations, **excludes** the **Compliant Network** location, and grants **Block**.
4. Under **Target resources** > exclude the **Microsoft Intune** and **Microsoft Intune Enrollment** apps.

#### Related links

* [Enable compliant network check with Conditional Access](https://learn.microsoft.com/entra/global-secure-access/how-to-compliant-network)
* [Source IP restoration](https://learn.microsoft.com/entra/global-secure-access/how-to-source-ip-restoration)

<!--- Results --->
%TestResult%
