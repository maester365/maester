Agent Identities should not have high-risk Microsoft Graph permissions.

Agent Identities can be granted Microsoft Graph application permissions and delegated permission
scopes. Some permissions provide a path to privileged control of the tenant if an Agent Identity is
compromised.

This check reports Agent Identities assigned permissions that Maester classifies as high risk and
that Microsoft does not currently list as blocked for Agent Identities. It evaluates application and
delegated grants together and identifies the permission type in each finding.

A **Direct** attack path can provide privileged control using the reported permission itself. An
**Indirect** attack path requires another permission, configuration, or identity to complete the
escalation path. The check evaluates the following permissions:

| Permission | Attack path |
| --- | --- |
| `AdministrativeUnit.ReadWrite.All` | Indirect |
| `DeviceManagementConfiguration.ReadWrite.All` | Indirect |
| `DeviceManagementRBAC.ReadWrite.All` | Indirect |
| `Policy.ReadWrite.ConditionalAccess` | Direct |
| `PrivilegedAccess.ReadWrite.AzureADGroup` | Direct |
| `PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup` | Direct |
| `PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup` | Indirect |
| `RoleAssignmentSchedule.ReadWrite.Directory` | Direct |
| `RoleEligibilitySchedule.ReadWrite.Directory` | Indirect |
| `RoleManagementPolicy.ReadWrite.AzureADGroup` | Indirect |
| `RoleManagementPolicy.ReadWrite.Directory` | Indirect |

### Remediation action:

1. Open the [Microsoft Entra admin center][agent-identities] and navigate to **Entra ID** >
   **Agents** > **Agent identities**.
2. Locate the reported Agent Identity using its object ID or display name, then review its granted
   permissions.
3. Confirm the business requirement with the Agent Identity's owner and sponsor. Determine whether
   the permission was assigned directly or inherited from its Agent Identity Blueprint.
4. Remove an unnecessary direct application or delegated grant. For an inherited delegated scope,
   update the Blueprint's inheritable permissions to use only the enumerated scopes its agents need.
5. If the permission is required, replace it with a narrower Microsoft Graph permission where
   possible and document the approved exception.
6. If the grant was unexpected, review the Agent Identity's audit and sign-in logs and rotate any
   credentials that might have been exposed.

### Related links

* [Manage agent identities in your organization][manage-agent-identities]
* [Microsoft Graph permissions blocked for agents][blocked-agent-permissions]
* [Microsoft Graph permissions reference][graph-permissions]
* [Maester high-risk permission research][maester-high-risk-permissions]

[agent-identities]: https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AgentIdentityListBlade
[manage-agent-identities]: https://learn.microsoft.com/entra/agent-id/manage-agent-identities-admin
[blocked-agent-permissions]: https://learn.microsoft.com/graph/api/resources/agentid-platform-overview?view=graph-rest-1.0#microsoft-graph-permissions-blocked-for-agents
[graph-permissions]: https://learn.microsoft.com/graph/permissions-reference
[maester-high-risk-permissions]: https://github.com/emiliensocchi/azure-tiering/tree/main/Microsoft%20Graph%20application%20permissions

<!--- Results --->
%TestResult%
