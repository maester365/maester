Subscriptions should be blocked from leaving and entering the tenant.

The tenant subscription policy controls whether subscription owners can move a subscription out of the tenant or bring one in from another tenant. Allowing subscriptions to leave can let a privileged user transfer a subscription and its resources to an external tenant. Allowing subscriptions to enter can let a user bring in a subscription they control, together with its resources and role assignments.

Since 1 May 2026 Microsoft blocks both directions by default for tenants that never set a policy. A tenant that set **Allow everyone** before then keeps that setting. This check also covers CIS Microsoft Azure Foundations Benchmark v6.0.0 recommendation 5.6.

#### Remediation action

1. Sign in to the [Azure portal](https://portal.azure.com) as a Global Administrator with a direct role assignment, and [elevate access](https://learn.microsoft.com/azure/role-based-access-control/elevate-access-global-admin) to manage all Azure subscriptions. Other users can read the policy but not change it.
2. Go to **Subscriptions** and select **Manage Policies**.
3. Set **Subscription leaving Microsoft Entra tenant** and **Subscription entering Microsoft Entra tenant** to **Permit no one**.
4. If specific users must still move subscriptions, add them to **Exempted Users**.
5. Select **Save changes**.

#### Related links

- [Manage Azure subscription policies - Microsoft Learn](https://learn.microsoft.com/azure/cost-management-billing/manage/manage-azure-subscription-policy)
- [Azure portal](https://portal.azure.com)

<!--- Results --->
%TestResult%
