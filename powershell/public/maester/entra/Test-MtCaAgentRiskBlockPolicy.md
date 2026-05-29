Checks whether your tenant has at least one enabled Conditional Access policy that blocks agent identities detected as high risk.

This check looks for enabled Microsoft Entra (Azure AD) Conditional Access policies that both target agent identity risk levels set to `High` and enforce a `Block` grant control. 
Agents (service or managed identities used by automation or AI) that are flagged as high risk by Entra ID Protection should be prevented from authenticating to prevent potentially compromised AI agents from accessing organizational resources.


#### Remediation action:

To remediate, create or update a Conditional Access policy that:


- Targets agent identities (agent ID risk conditions).
- Sets `agentIdRiskLevels` to include `high`.
- Uses a grant control that includes the built-in `Block` action.

Refer to Microsoft documentation when creating policies to ensure correct targeting and scope.

#### Related links

- Microsoft doc: https://learn.microsoft.com/entra/identity/conditional-access/policy-agent-block-high-risk

