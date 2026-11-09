Open Entra ID Protection user risk detections should be reviewed.

Entra ID Protection raises a risk detection for each suspicious sign-in or account event it sees: a password guessed in a password spray, a sign-in through an attacker-in-the-middle proxy, a password found in a leak, an authentication method registered by someone who is not the user, a mailbox rule that forwards mail outside the organization, and more. Each detection stays open (**atRisk**) until someone remediates it, dismisses it or confirms it safe. Open detections that nobody reviews are signs of compromise that nobody is acting on, and Graph only keeps them for 90 days.

Maester creates one result per detection type (MT.1273.&lt;riskEventType&gt;), so the report shows which kinds of signal are waiting. A result fails when at least one detection of its type has the risk state **atRisk** or **confirmedCompromised**, and lists those detections with the high-risk ones first. Detections that have been remediated, dismissed or confirmed safe pass. Each result starts with a short explanation of its detection type and a link to Microsoft's investigation tips. The severity of each result reflects how strong a sign of compromise that detection type is.

Detection types that need Microsoft Entra ID P2 are skipped in tenants without it; those tenants see such detections as **Additional risk detected** (generic). Detection types that come from Microsoft Defender for Cloud Apps, Defender for Endpoint or Defender for Office 365 only fire when the tenant uses those products, and otherwise pass. A detection type that Microsoft adds later, and that Maester does not know yet, gets a result of its own when it has open detections.

This check reads the detections behind the risk. MT.1260 reports the users that are high risk and unremediated; the two complement each other.

The check reads identityProtection/riskDetections with the Microsoft Graph permission IdentityRiskEvent.Read.All, which Maester requests by default. It never changes a user's risk.

#### Remediation action

The security operations team should review every open detection and close it one way or the other.

1. Open the [Microsoft Entra admin center](https://entra.microsoft.com) and go to **ID Protection** > **Risk detections**. Filter by **Detection type** and by **Risk state** = **At risk**. Start with high-risk detections and with users who hold an admin role.
2. Investigate each detection: the user's sign-ins around the detection time, the IP address and location, recent changes to the user's authentication methods, mailbox rules and app consents. Confirm with the user through a channel the attacker cannot control.
3. If the activity is legitimate, close it: in **Risky sign-ins** select **Confirm sign-in safe**, or in **Risky users** select **Dismiss user risk**.
4. If the account is compromised, select **Confirm user compromised** and remediate:
   - require a secure password reset and revoke the user's sessions;
   - remove any authentication method, device, inbox rule or app consent the attacker added. A password reset alone does not remove an attacker's MFA method;
   - check what the account accessed while it was compromised.
5. To keep the queue short, use risk-based Conditional Access policies that require risk remediation, so users clear most user and sign-in risk themselves.

#### Related links

* [What are risk detections?](https://learn.microsoft.com/entra/id-protection/concept-identity-protection-risks)
* [Investigate risk with Microsoft Entra ID Protection](https://learn.microsoft.com/entra/id-protection/howto-identity-protection-investigate-risk)
* [Remediate risks and unblock users](https://learn.microsoft.com/entra/id-protection/howto-identity-protection-remediate-unblock)
* [Provide feedback on risk detections](https://learn.microsoft.com/entra/id-protection/howto-identity-protection-risk-feedback)

<!--- Results --->
%TestResult%
