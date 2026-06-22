When Private DNS is hosted on the Quick Access application, the Global Secure Access client's DNS queries authenticate against the Quick Access app and are evaluated by Conditional Access. A **sign-in frequency** session control then re-triggers on those frequent DNS lookups, causing unexpected and repeated authentication prompts. Microsoft recommends not applying a sign-in frequency control to Quick Access.

This is an operational / user-experience hygiene check, not a security gap. The fix is to exclude the Quick Access app from the sign-in frequency policy - the MFA grant and the control for everything else stay in place.

#### Remediation action:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a **Conditional Access Administrator**.
2. Browse to **Entra ID** > **Conditional Access** > **Policies** and open each flagged policy.
3. Under **Target resources**, exclude the **Quick Access** application (do not remove the sign-in frequency control organization-wide).

#### Related links

* [Apply Conditional Access to Private Access apps](https://learn.microsoft.com/entra/global-secure-access/how-to-target-resource-private-access-apps)
* [Conditional Access session controls - sign-in frequency](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-session#sign-in-frequency)

<!--- Results --->
%TestResult%
