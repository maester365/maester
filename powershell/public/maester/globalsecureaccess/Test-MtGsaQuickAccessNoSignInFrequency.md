When Private DNS is hosted on the Quick Access application, the Global Secure Access client's DNS queries authenticate against the Quick Access app and are evaluated by Conditional Access. A **sign-in frequency** session control then re-triggers on those frequent DNS lookups, causing unexpected and repeated authentication prompts. Microsoft recommends not applying a sign-in frequency control to Quick Access.

This is an operational / user-experience hygiene check, not a security gap. The fix is to exclude the Quick Access app from the sign-in frequency policy - the MFA grant and the control for everything else stay in place.

An enabled sign-in frequency policy that targets Quick Access is a **Fail**, unless it falls into a category that does not drive routine DNS prompts, which is surfaced for **Review** instead:

* **Role-only** - scoped only to directory roles (e.g. admins), who typically do not use Private Access.
* **Guest** - scoped to guest / external users, who very rarely use Private Access.
* **Risk-gated** - has a user- or sign-in-risk condition, so the control only applies under elevated risk.
* **Browser** - limited to the `browser` client app type; Private Access / Quick Access traffic is not browser-based.

Reviewed, accepted exceptions can be **allow-listed** by policy id or display name via the `GsaQuickAccessSignInFrequencyAllowedPolicies` global setting in `maester-config.json`; those are reported as **Accepted** and never fail.

#### Remediation action:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a **Conditional Access Administrator**.
2. Browse to **Entra ID** > **Conditional Access** > **Policies** and open each **Fail** policy.
3. Under **Target resources**, exclude the **Quick Access** application (do not remove the sign-in frequency control organization-wide).

#### Related links

* [Apply Conditional Access to Private Access apps](https://learn.microsoft.com/entra/global-secure-access/how-to-target-resource-private-access-apps)
* [Conditional Access session controls - sign-in frequency](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-session#sign-in-frequency)

<!--- Results --->
%TestResult%
