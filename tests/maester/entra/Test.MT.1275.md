Every Conditional Access policy plan should record an accountable owner.

Owner metadata helps administrators identify the team responsible for reviewing and maintaining a plan. Missing metadata is a governance hygiene finding: it does not disable policy enforcement. Plan ownership grants no administrator role or edit permission.

This check examines only whether the `owners` collection contains an entry. It does not resolve owner IDs, verify account activity, or inspect group members. A deleted user ID can remain recorded on a plan and will therefore pass this presence check. Owner lifecycle and approval reachability require separate validation.

Plans are optional. A tenant with no plans is **NotApplicable**, including a tenant protected entirely by standalone Conditional Access policies. A failed API read is an error, not an empty inventory.

#### Remediation action

1. In **Entra ID**, open **Conditional Access** > **[Policy plans (Preview)](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/PolicyPlans/menuId/Policies)**.
2. Review the plans listed in the result and agree with the relevant administrators or application teams who is accountable for each plan.
3. Open each plan, select **Edit plan**, add the responsible individual or group under **Owners**, and save.
4. Include the recorded owners in the organization's ownership review process. Grant administrative permissions separately only when the person's job requires them.

The recommended fix changes accountability metadata and does not disrupt end-user sign-ins. Coordinating responsibility across the affected teams may require work beyond the portal edit itself.

#### Related links

- [Conditional Access policy plans](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-policy-plans)
- [Create and maintain a policy plan](https://learn.microsoft.com/entra/identity/conditional-access/how-to-create-conditional-access-policy-plan)
- [Policy plan owner metadata](https://learn.microsoft.com/graph/api/conditionalaccesspolicyplan-update?view=graph-rest-beta)

<!--- Results --->
%TestResult%
