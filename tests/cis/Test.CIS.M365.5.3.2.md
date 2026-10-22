A recurring access review of guest users exists, repeats at least monthly and applies its decisions automatically.

Guest accounts are created for a project and then forgotten. Each one keeps its access, and the external organisation that owns the identity can change or lose control of it without you noticing. A regular access review asks the owners to confirm that each guest still needs access, and removes those who are not confirmed.

The review must repeat weekly or monthly, give reviewers no more than 14 days, send notifications and reminders, ask for a justification when access is approved, apply results automatically, deny access when no one responds and have no end date. Access reviews need Microsoft Entra ID Governance or Microsoft Entra ID P2 licences.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **ID Governance** > [**Access reviews**](https://entra.microsoft.com/#view/Microsoft_AAD_ERM/DashboardBlade/~/Controls/menuId/) and select **New access review**.
3. Select **Teams + Groups** and choose **All Microsoft 365 groups with guest users** (or a selected set of groups).
4. Under **Scope**, choose **Guest users only**.
5. Set the reviewers, a **Weekly** or **Monthly** recurrence, a duration of 14 days or less and **No end date**.
6. Under **Upon completion settings**, turn on **Auto apply results to resource** and set **If reviewers don't respond** to **Remove access**.
7. Under **Advanced settings**, turn on **Require reason on approval**, **Mail notifications** and **Reminders**, then create the review.

#### Related links

* [Microsoft Entra admin center - Access reviews](https://entra.microsoft.com/#view/Microsoft_AAD_ERM/DashboardBlade/~/Controls/menuId/)
* [Create an access review of groups and applications in Microsoft Entra ID](https://learn.microsoft.com/entra/id-governance/create-access-review)
* [Manage guest access with access reviews](https://learn.microsoft.com/entra/id-governance/manage-guest-access-with-access-reviews)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.3.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
