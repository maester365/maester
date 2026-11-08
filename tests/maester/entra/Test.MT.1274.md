Open Entra ID Protection workload identity risk detections should be reviewed.

Entra ID Protection raises risk detections for workload identities (service principals) as well as users: a client secret found in public code, sign-ins from an unusual place or with an unusual credential, unusual Microsoft Graph traffic, threat intelligence matches, and apps that Microsoft has found or disabled as malicious. Each detection stays open (**atRisk**) until someone remediates or dismisses it. A service principal cannot answer an MFA prompt, so a stolen credential works until it is removed, and an open detection nobody reviews leaves that door open. Graph keeps detections for 90 days.

Maester creates one result per detection type (MT.1274.&lt;riskEventType&gt;), so the report shows which kinds of signal are waiting. A result fails when at least one detection of its type has the risk state **atRisk** or **confirmedCompromised**, and lists those detections with the high-risk ones first. Detections that have been remediated or dismissed pass. Each result starts with a short explanation of its detection type. The severity of each result reflects how strong a sign of compromise that detection type is. A detection type that Microsoft adds later, and that Maester does not know yet, gets a result of its own when it has open detections.

This check reads the detections behind the risk. MT.1262 and MT.1263 report the service principals that are high or medium risk; the checks complement each other.

The check needs a Microsoft Entra Workload ID Premium licence, which the servicePrincipalRiskDetections API requires; tenants without it skip the check as not licensed. It reads identityProtection/servicePrincipalRiskDetections with the Microsoft Graph permission IdentityRiskEvent.Read.All, which Maester requests by default. It never changes a service principal's risk.

#### Remediation action

The security operations team should review every open detection and close it one way or the other.

1. Open the [Microsoft Entra admin center](https://entra.microsoft.com) and go to **ID Protection** > **Risk detections** > **Workload identity detections**. Start with high-risk detections and with service principals that hold privileged app roles or directory roles.
2. Investigate each service principal: its sign-ins, recent changes to its credentials, owners and app roles, and its configuration changes in the audit log.
3. If the activity is legitimate, go to **ID Protection** > **Risky workload identities** and select **Dismiss risk**.
4. If the service principal is compromised, select **Confirm compromised**, then:
   - inventory the credentials of the service principal and its application object, add a new credential (preferably a certificate) and remove all the old ones;
   - rotate any Azure Key Vault secrets the service principal can read;
   - remove app roles, owners or permissions an attacker added, or disable the service principal until it is clean.
5. To block risky workload identities automatically, use a Conditional Access policy for workload identities with the service principal risk condition.

#### Related links

* [Securing workload identities with Microsoft Entra ID Protection](https://learn.microsoft.com/entra/id-protection/concept-workload-identity-risk)
* [Conditional Access for workload identities](https://learn.microsoft.com/entra/identity/conditional-access/workload-identity)
* [Microsoft Entra security operations guide for applications](https://learn.microsoft.com/entra/architecture/security-operations-applications)

<!--- Results --->
%TestResult%
