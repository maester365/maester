Medium-risk service principals should not be left unremediated in Entra ID Protection.

Entra ID Protection rates the risk of workload identities (service principals) and tracks a risk state for each flagged one. Signals include leaked credentials, suspicious sign-ins, suspicious API traffic and Microsoft threat intelligence. A medium-risk flag only clears when an admin remediates or dismisses it. Until then the signals that triggered the flag have not been addressed, and unlike a user, a service principal can't be stopped by multifactor authentication. Dismissing a flag clears it but does not remove compromised credentials, so investigate first.

This check reports service principals whose risk level is **medium** and whose risk state is still active and unremediated (`atRisk` or `confirmedCompromised`). States that represent a handled flag (`remediated`, `dismissed`, `confirmedSafe`, `none`) are not reported. The check reads risk only and never changes a service principal's risk state.

If a reported service principal holds a privileged directory role, active or PIM-eligible, the result lists the role and shows that entry first, since a compromised app with admin rights puts the whole tenant at risk.

The check needs a Microsoft Entra Workload ID Premium licence, which the risky service principals API requires. Tenants without it skip the check as not licensed. It also needs the Microsoft Graph permission `IdentityRiskyServicePrincipal.Read.All`, which Maester does not request by default. Without it the check is skipped. To identify privileged service principals, it also reads directory roles, which needs `RoleManagement.Read.Directory` or `RoleManagement.Read.All`. If those reads fail, the service principals are still reported with a note. Connect with `Connect-Maester -IncludePreview`, or grant the permission to the app registration that runs Maester.

This is the medium-risk companion to MT.1262, which reports high-risk service principals, and the service principal counterpart to MT.1261, which reports medium-risk users.

#### Remediation action

1. Open the [Microsoft Entra admin center](https://entra.microsoft.com) and navigate to **ID Protection** > **Risky workload identities**.
2. Locate each reported service principal by its name or application ID. Start with any service principal listed with a privileged role.
3. Investigate the risk detections behind the flag: look for suspicious sign-ins, unauthorized credential or configuration changes, and application roles the app should not have.
4. If the service principal is compromised:
   - Inventory the credentials on the service principal and its application object.
   - Add a new credential (Microsoft recommends a certificate), then remove the compromised credentials. If in doubt, remove all existing credentials.
   - Rotate any Azure Key Vault secrets the service principal can access.
   - Disable the service principal if it must be blocked while you investigate.
5. If the activity is confirmed safe after investigation, dismiss the risk so the flag clears.
6. Consider a risk-based Conditional Access policy for workload identities so that risky service principals are blocked automatically rather than left waiting for manual review.

#### Related links

* [Securing workload identities with ID Protection](https://learn.microsoft.com/entra/id-protection/concept-workload-identity-risk)
* [Conditional Access for workload identities](https://learn.microsoft.com/entra/identity/conditional-access/workload-identity)
* [riskyServicePrincipal resource type](https://learn.microsoft.com/graph/api/resources/riskyserviceprincipal)

<!--- Results --->
%TestResult%
