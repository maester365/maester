Every Entra Private Access (and Quick Access) application should be protected by an enabled Conditional Access policy that requires multifactor authentication - either by targeting the application directly or via All cloud apps. Without an MFA gate, a per-app tunnel exposes the internal application to single-factor access.

A policy satisfies the requirement when it grants **MFA** or requires an **authentication strength** (for example FIDO2 or phishing-resistant MFA, which are MFA-grade).

This check evaluates application coverage only; it does not evaluate whether the policy applies to every user of the app.

#### Remediation action:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a **Conditional Access Administrator**.
2. Browse to **Entra ID** > **Conditional Access** > **Policies**.
3. Create or edit an enabled policy that targets the listed Private Access applications (or **All cloud apps**) and, under **Grant**, requires **multifactor authentication** (or an authentication strength).
4. Set **Enable policy** to **On** and save.

#### Related links

* [Apply Conditional Access to Private Access apps](https://learn.microsoft.com/entra/global-secure-access/how-to-target-resource-private-access-apps)
* [Conditional Access authentication strength](https://learn.microsoft.com/entra/identity/authentication/concept-authentication-strengths)

<!--- Results --->
%TestResult%
