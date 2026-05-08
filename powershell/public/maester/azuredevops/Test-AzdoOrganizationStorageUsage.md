Azure Artifacts provides 2 GiB of free storage for each organization. Once your organization reaches the maximum storage limit, you will not be able to publish new artifacts. To continue, you can either delete some of your existing artifacts or increase your storage limit.

Rationale: The storage limit should not be reached; hitting it blocks artifact publication.


#### Remediation action:
- [Configure retention policies](https://learn.microsoft.com/en-us/azure/devops/artifacts/how-to/delete-and-recover-packages?view=azure-devops&tabs=nuget#delete-packages-automatically-with-retention-policies)
- [Set up billing](https://learn.microsoft.com/en-us/azure/devops/organizations/billing/set-up-billing-for-your-organization-vs?view=azure-devops#set-up-billing)
- Increase Artifacts storage limit
  - [Set up billing for your organization.](https://learn.microsoft.com/en-us/azure/devops/organizations/billing/set-up-billing-for-your-organization-vs?view=azure-devops#set-up-billing)
  - Sign in to your Azure DevOps organization, select Organization settings > Billing, and select No limit, pay for what you use from the Usage limit dropdown.
  - Select Save when you are done.

#### Related links

* [Learn - Package size and count limits](https://learn.microsoft.com/en-us/azure/devops/artifacts/reference/limits?view=azure-devops)
