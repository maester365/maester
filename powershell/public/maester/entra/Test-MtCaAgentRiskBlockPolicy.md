Checks whether your tenant has at least one enabled Conditional Access policy that blocks agent identities detected as high risk.

This check looks for enabled Microsoft Entra (Azure AD) Conditional Access policies that target agent identity with risk levels set to `High` and enforce a `Block` grant control.
Agents (service or managed identities used by automation or AI) that are flagged as high risk by Entra ID Protection should be prevented from authenticating to prevent potentially compromised AI agents from accessing organizational resources.


#### Remediation action:

To remediate, create or update a Conditional Access policy that:


- Users or agents: all agent identities.
- Target resources: All resources (formerly 'All cloud apps')
- Conditions: `Agent risk` to include `high`.
- Uses a grant control that includes the `Block` action.

Refer to Microsoft documentation when creating policies to ensure correct targeting and scope.

#### Related links

- Microsoft doc: https://learn.microsoft.com/entra/identity/conditional-access/policy-agent-block-high-risk

