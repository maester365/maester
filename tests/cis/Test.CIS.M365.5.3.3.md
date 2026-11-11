The Global, Exchange, SharePoint, Teams, Security and Privileged Role Administrator roles each have a recurring access review that is configured as required.

Role assignments accumulate: people change jobs, projects end and temporary access becomes permanent. A recurring review makes the people who know the context confirm who still needs each privileged role, and removes the others.

Each of the six roles needs an active review that covers users and groups, repeats at least monthly (weekly every 1 to 4 weeks, or monthly every month), gives reviewers 14 days or less, sends notifications and reminders, asks for a justification when approving, applies results automatically, uses the default decision of **No change** and does not end. Access reviews need Microsoft Entra ID Governance or Microsoft Entra ID P2 licences.

**Note on recurrence:** The CIS Graph audit only checks that `recurrence.pattern.type` is `weekly` or `absoluteMonthly` and does not constrain `interval`. This check follows the benchmark's "monthly or more frequent" recommendation instead, so it is stricter than the literal audit. It fails a weekly review with an interval above 4 and a monthly review with an interval above 1.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Expand **ID Governance** > **Privileged Identity Management**.
3. For **Microsoft Entra roles**, select **Microsoft Entra roles**.
4. Under **Manage**, select **Microsoft Entra roles**, then select **Access reviews** and **New**.
5. Provide a name and description, then set:
   - **Frequency** to **Monthly** or more frequently.
   - **Duration (in days)** to **14** or less and shorter than the selected recurrence interval; PIM does not allow recurring reviews to overlap.
   - **End** to **Never**.
   - **Users scope** to **All users and groups**.
   - **Role** to the roles listed above. One review is created for each role selected.
   - **Assignment type** to **All active and eligible assignments**.
   - **Reviewers** to the members responsible for this review, other than the role holders themselves.
6. Under **Upon completion settings**, turn on **Auto apply results to resource** and set **If reviewers don't respond** to **No change**.
7. Under **Advanced settings**, turn on **Require reason on approval**, **Mail notifications** and **Reminders**.
8. Select **Start** to save and begin the review series.

**Warning:** Be careful with **If reviewers don't respond** on Global Administrator reviews. A misconfiguration can remove roles from break-glass accounts. Tell reviewers what break-glass accounts are so they do not remove them by mistake.

To create or update the reviews with the Microsoft Graph API, send a `POST` to `v1.0/identityGovernance/accessReviews/definitions` with a body that meets the settings above. To update an existing review, send a `PUT` with the full writable object to `v1.0/identityGovernance/accessReviews/definitions/{review-id}`. The `scope` cannot be changed by an update, so create a new review if an existing one targets the wrong role or excludes groups.

#### Review updates

Definition updates apply only to future review instances; a currently running instance keeps its existing settings. Graph only allows the `reviewers` property to be updated when individual users are already assigned as reviewers, so create a new review to replace a self-review with named reviewers.

#### Related links
* [Microsoft Entra admin center - Privileged Identity Management](https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/ResourceMenuBlade/~/roles/resourceId//resourceType/tenant/provider/aadroles)
* [Create an access review of Azure resource and Microsoft Entra roles in PIM](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-create-roles-and-resource-roles-review)
* [Create an access review of groups and applications in Microsoft Entra ID](https://learn.microsoft.com/entra/id-governance/create-access-review)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.3.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
