Global Secure Access Conditional Access signaling restores the original client source IP to Microsoft Entra ID and Microsoft 365, and enables the **Compliant Network** named location used for token replay protection in Conditional Access.

Without signaling, IP-based Conditional Access location policies and Identity Protection risk detections lose the user's real egress IP address, and the Compliant Network signal is unavailable.

#### Remediation action:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a **Global Secure Access Administrator**.
2. Browse to **Global Secure Access** > **Settings** > **Session management** > **Adaptive Access**.
3. Enable **Conditional Access Signaling for Microsoft Entra ID**.

#### Related links

* [Source IP restoration](https://learn.microsoft.com/entra/global-secure-access/how-to-source-ip-restoration)
* [Universal Conditional Access through Global Secure Access](https://learn.microsoft.com/entra/global-secure-access/concept-universal-conditional-access)

<!--- Results --->
%TestResult%
