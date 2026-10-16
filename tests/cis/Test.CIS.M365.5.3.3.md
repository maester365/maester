The Global, Exchange, SharePoint, Teams and Security Administrator roles each have a recurring access review that is configured as required.

Role assignments accumulate: people change jobs, projects end and temporary access becomes permanent. A recurring review makes the people who know the context confirm who still needs each privileged role, and removes the others.

Each of the five roles needs an active review that covers users and groups, repeats weekly or monthly, gives reviewers 14 days or less, sends notifications and reminders, asks for a justification when approving, applies results automatically, uses the default decision of **No review** and does not end. Access reviews need Microsoft Entra ID Governance or Microsoft Entra ID P2 licences.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **ID Governance** > **Privileged Identity Management** > **Microsoft Entra roles** > **Access reviews** and select **New**.
3. Select the review scope **Users and Groups**, add the role to review (for example Global Administrator) and choose the **Assignment type**.
4. Set the reviewers, a **Weekly** or **Monthly** recurrence, a duration of 14 days or less and **No end date**.
5. Under **Upon completion settings**, turn on **Auto apply results to resource** and set **If reviewers don't respond** to **No change**.
6. Under **Advanced settings**, turn on **Require reason on approval**, **Mail notifications** and **Reminders**, then start the review.
7. Repeat for the other roles in the list.

#### Related links

* [Microsoft Entra admin center - Privileged Identity Management](https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/ResourceMenuBlade/~/roles/resourceId//resourceType/tenant/provider/aadroles)
* [Create an access review of Azure resource and Microsoft Entra roles in PIM](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-create-roles-and-resource-roles-review)
* [Create an access review of groups and applications in Microsoft Entra ID](https://learn.microsoft.com/entra/id-governance/create-access-review)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.3.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
