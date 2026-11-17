A recurring access review of guest users exists, repeats monthly or more frequently and removes access when reviewers do not respond.

Guest accounts are created for a project and then forgotten. Each one keeps its access, and the external organisation that owns the identity can change or lose control of it without you noticing. A regular access review asks the owners to confirm that each guest still needs access, and removes those who are not confirmed.

The review must repeat at least monthly: weekly (every 1 to 4 weeks) or monthly (every month), give reviewers no more than 14 days, send notifications and reminders, ask for a justification when access is approved, apply results automatically, deny access when no one responds and have no end date. Access reviews need Microsoft Entra ID Governance or Microsoft Entra ID P2 licences.

**Note on recurrence:** The CIS Graph audit only checks that `recurrence.pattern.type` is `weekly` or `absoluteMonthly` and does not constrain `interval`. This check follows the benchmark's "monthly or more frequent" recommendation instead, so it is stricter than the literal audit. It fails a weekly review with an interval above 4 and a monthly review with an interval above 1.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Expand **ID Governance**, select [**Access reviews**](https://entra.microsoft.com/#view/Microsoft_AAD_ERM/DashboardBlade/~/Controls/menuId/) and select **New access review**.
3. In the **Resource review** box (labelled **Review access to a resource type** in newer portal versions), select **Select**.
4. On **Review Type**, set **Select what to review** to **Teams + Groups**, **Review Scope** to **All Microsoft 365 groups with guest users** and **Scope** to **Guest users only**, then select **Next: Reviews**.
5. On **Reviews**, set:
   - **Select reviewers** to **Group members** or **Selected users and groups** (the portal may list **Group owner(s)** instead of **Group members**). Assign at least one reviewer and make sure guests do not review themselves. If you choose **Group owner(s)**, also assign fallback reviewers, because a group without an owner has no reviewer and, with the removal setting below, its guests could lose access without being reviewed.
   - **Duration (in days)** to **14** or less.
   - **Review recurrence** to **Monthly** or more frequent.
   - **Start date** so the review becomes active before the next audit date.
   - **End** to **Never**, then select **Next: Settings**.
6. On **Settings**, turn on **Auto apply results to resource**, set **If reviewers don't respond** to **Remove access**, and turn on **Justification required**, **E-mail notifications** and **Reminders**. Select **Next: Review + Create**.
7. Select **Create**.

**Scope limits:** **All Microsoft 365 groups with guest users** does not include dynamic groups or role-assignable groups, and the review does not cover guests who have access through security groups or applications. Create separate access reviews for those if you need them.

To create or update the review with the Microsoft Graph API, send a `POST` to `v1.0/identityGovernance/accessReviews/definitions` with a body that meets the settings above. To update an existing review, send a `PUT` with the full writable object to `v1.0/identityGovernance/accessReviews/definitions/{review-id}`. The `scope` cannot be changed by an update, so create a new review if the existing one targets the wrong scope.

#### Review updates

Definition updates apply only to future review instances; a currently running instance keeps its existing settings.

#### Related links
* [Microsoft Entra admin center - Access reviews](https://entra.microsoft.com/#view/Microsoft_AAD_ERM/DashboardBlade/~/Controls/menuId/)
* [Create an access review of groups and applications in Microsoft Entra ID](https://learn.microsoft.com/entra/id-governance/create-access-review)
* [Manage guest access with access reviews](https://learn.microsoft.com/entra/id-governance/manage-guest-access-with-access-reviews)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.3.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
