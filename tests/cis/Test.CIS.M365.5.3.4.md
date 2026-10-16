Activating the Global Administrator role in Privileged Identity Management needs approval from at least one other person.

Global Administrator can change anything in the tenant. If an attacker gets an eligible account, MFA is the only barrier to activating the role. Requiring approval adds a second person who can refuse an activation that looks wrong, and creates a record of why it was granted.

Approval slows urgent changes, so define more than one approver and agree how to handle out-of-hours requests. Microsoft Entra ID P2 or Microsoft Entra ID Governance licences are required.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to [Privileged Identity Management](https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/ResourceMenuBlade/~/roles/resourceId//resourceType/tenant/provider/aadroles) > **Microsoft Entra roles** > **Roles** and select **Global Administrator**.
3. Select **Role settings** > **Edit**.
4. On the **Activation** tab, select **Require approval to activate** and **Select approvers**. Add at least one user or group.
5. Select **Update**.

#### Related links

* [Microsoft Entra admin center - Privileged Identity Management](https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/ResourceMenuBlade/~/roles/resourceId//resourceType/tenant/provider/aadroles)
* [Approve or deny requests for Microsoft Entra roles in PIM](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-approval-workflow)
* [Configure Microsoft Entra role settings in PIM](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-how-to-change-default-settings)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.3.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
