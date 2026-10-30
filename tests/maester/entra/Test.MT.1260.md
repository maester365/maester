High-risk users should not be left unremediated in Entra ID Protection.

Entra ID Protection rates a user's risk and tracks a risk state for each flagged user. A high-risk flag only clears when the risk is remediated, for example by a password reset, or when an admin dismisses it or confirms the user safe. Until then the account stays exposed: the signals that triggered the flag have not been addressed.

This check reports users whose risk level is **high** and whose risk state is still active and unremediated (`atRisk` or `confirmedCompromised`). States that represent a handled flag (`remediated`, `dismissed`, `confirmedSafe`, `none`) are not reported. The check reads risk only and never changes a user's risk state.

If a reported user holds a privileged directory role, active or PIM-eligible, the result lists the role and the severity is raised to High, since a compromised admin account puts the whole tenant at risk.

The check needs the Microsoft Graph permission `IdentityRiskyUser.Read.All`, which Maester does not request by default. Without it the check is skipped. Connect with `Connect-Maester -IncludePreview`, or grant the permission to the app registration that runs Maester.

A companion check, MT.1261, is planned to report on medium-risk users. This check is about the outcome (users actually left unremediated). It is complementary to MT.1253, which checks that a Conditional Access policy requiring risk remediation is in place; one checks the control, this one checks the result.

#### Remediation action

1. Open the [Microsoft Entra admin center](https://entra.microsoft.com) and navigate to **Protection** > **Identity Protection** > **Risky users**.
2. Locate each reported user by their user principal name. Start with any user listed with a privileged role.
3. Investigate the risk detections behind the flag and decide whether the account is compromised.
4. Remediate the risk by the appropriate path:
   - If compromised, require a password reset, revoke the user's refresh tokens, and review recent sign-ins and activity.
   - If the activity is confirmed safe after investigation, dismiss the user's risk or confirm the user safe so the flag clears.
5. Consider a risk-based Conditional Access policy so that future high-risk users are remediated automatically rather than left waiting for manual review.

#### Related links

* [Remediate risks and unblock users](https://learn.microsoft.com/entra/id-protection/howto-identity-protection-remediate-unblock)
* [Investigate risk with Microsoft Entra ID Protection](https://learn.microsoft.com/entra/id-protection/howto-identity-protection-investigate-risk)
* [What is risk in Microsoft Entra ID Protection](https://learn.microsoft.com/entra/id-protection/concept-identity-protection-risks)

<!--- Results --->
%TestResult%
