High-risk agents should not be left unremediated in Entra ID Protection.

Entra ID Protection rates the risk of agents (Microsoft Entra Agent ID) and tracks a risk state for each flagged one. This covers agent identities, agent identity blueprint principals and agents' user accounts. Signals include anomalous sign-ins, reconnaissance of the directory, failed attempts to reach resources the agent isn't authorized for, new credentials added to a blueprint and then used, and Microsoft threat intelligence. Microsoft documents admin actions, **Confirm safe** and **Dismiss risk**, as the way to clear an agent's risk, and until then the signals that triggered the flag have not been addressed. An agent can't be sent through multifactor authentication the way a risky user can: for agent risk, Conditional Access can only block, so the flag is left for an admin to handle. Dismissing a flag clears it but does not remove compromised credentials, so investigate first.

This check reports agents whose risk level is **high** and whose risk state is still active and unremediated (`atRisk` or `confirmedCompromised`). States that represent a handled flag (`dismissed`, `confirmedSafe`, `remediated`, `none`) are not reported. Deleted agents are not reported, because a deleted agent cannot sign in and leaves nothing to act on. Disabled agents are still reported, because disabling only blocks sign-ins: the risk stays open until an admin dismisses it or confirms the agent safe. The check reads risk only and never changes an agent's risk state.

If a reported agent holds a privileged directory role, active or PIM-eligible, the result lists the role and shows that entry first, since a compromised agent with admin rights puts the whole tenant at risk.

The check needs Microsoft Entra ID P2 and Microsoft Agent 365: ID Protection for agents needs P2 during the preview, and Microsoft says it will require Agent 365. Tenants without both skip the check as not licensed. It also needs the Microsoft Graph permission `IdentityRiskyAgent.Read.All`, which Maester does not request by default. Without it the check is skipped. To identify privileged agents, it also reads directory roles, which needs `RoleManagement.Read.Directory` or `RoleManagement.Read.All`. If those reads fail, the agents are still reported with a note. Connect with `Connect-Maester -IncludePreview`, or grant the permission to the app registration that runs Maester.

This is the agent companion to MT.1262, which reports high-risk service principals. Entra ID Protection reports agent risk in its own list, `riskyAgents`, which MT.1262 does not read. MT.1285 reports medium-risk agents.

#### Remediation action

1. Open the [Microsoft Entra admin center](https://entra.microsoft.com) and navigate to **ID Protection** > **Risky agents**.
2. Locate each reported agent by its name or object ID. Start with any agent listed with a privileged role.
3. Open the agent's risk detections and investigate them: look for sign-ins or resource access the agent shouldn't make, credentials added to its blueprint, and permissions or roles the agent should not have.
4. If the agent is compromised:
   - Disable the agent so it stops signing in while you investigate.
   - Remove the compromised credentials from the agent identity blueprint and add new ones.
   - Remove permissions and roles the agent doesn't need.
5. If the activity is confirmed safe after investigation, select **Confirm safe**, or **Dismiss risk** if the activity was expected, so the flag clears.
6. Consider a risk-based Conditional Access policy for agents so that risky agents are blocked automatically rather than left waiting for manual review.

#### Known limitations

* **Beta API.** Microsoft publishes the risky agents list (`riskyAgents`) in Microsoft Graph beta only, so its shape can change.
* **Agent type.** The type comes from each item's `@odata.type`, with `identityType` as the fallback. Some of these values are new enum members that Graph returns as `unknownFutureValue` unless the request asks for them, and Maester's Graph requests don't. An agent whose type can't be read is still reported, with the type **Other agent**, but isn't listed on the report's affected objects page.
* **Risk detail.** Microsoft documents the agent values of Risk detail (`adminConfirmedAgentCompromised`, `adminConfirmedAgentSafe`, `adminDismissedRiskForAgent`) as new enum members that Graph returns only when the request asks for them. In testing, Graph returned `adminConfirmedAgentCompromised` without being asked. If Graph does withhold one, the column says so and points to the Risky agents report.
* **Privileged means directory roles.** The Privileged role column lists only built-in directory roles that Microsoft classifies as privileged, active or PIM-eligible. Custom roles and Microsoft Graph application permissions are not checked, so an agent that holds powerful Graph permissions but no privileged built-in role shows `None`. Only roles assigned directly to the agent are matched: a role held through membership of a role-assignable group isn't detected.
* **PIM-eligible roles.** Eligible role assignments are checked only when the tenant has Microsoft Entra ID P2 or Microsoft Entra ID Governance. Otherwise only active assignments are checked, and when the check reports agents the result includes a note saying so.

#### Related links

* [ID Protection for agents](https://learn.microsoft.com/entra/id-protection/concept-risky-agents)
* [Conditional Access for agents](https://learn.microsoft.com/entra/identity/conditional-access/agent-id)
* [riskyAgent resource type](https://learn.microsoft.com/graph/api/resources/riskyagent?view=graph-rest-beta)

<!--- Results --->
%TestResult%
