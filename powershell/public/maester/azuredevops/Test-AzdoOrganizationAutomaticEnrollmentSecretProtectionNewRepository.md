The GitHub Secret Protection plan **should be** automatically enabled on newly created Git repositories.

Rationale: Secret Protection provides push protection to prevent secret leaks before they happen, secret scanning alerts to catch existing exposures, and a security overview of your organization's risk. When automatic enablement is off, every new repository starts unprotected and has to be onboarded manually, so coverage silently degrades as the organization grows.

#### Remediation action:
Enable automatic enrollment of the Secret Protection plan for new repositories.
1. Sign in to your organization.
2. Choose **Organization settings** > **Repos** > **Repositories**.
3. Toggle **Secret Protection plan** to on, then select **Begin billing** to activate the plan.
4. Optionally select **Options** to also enable push protection for the repositories that are enrolled.

**Results:**
With automatic enablement on, any Git repository created in the organization from that point on has Secret Protection enabled at creation.

This setting has no effect on repositories that already exist. They must be enrolled separately using **Enable all**, which is assessed by AZDO.1040. A passing result here does not mean the organization is covered.

This test only applies to organizations that use the separate GitHub Secret Protection and GitHub Code Security plans. Organizations on the bundled GitHub Advanced Security for Azure DevOps SKU are skipped, because automatic enablement for the bundled SKU is reported by AZDO.1026 instead.

#### Related links

* [Learn - Configure GitHub Advanced Security features](https://learn.microsoft.com/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops#organization-level-onboarding)
* [Learn - Manage Advanced Security permissions](https://learn.microsoft.com/azure/devops/repos/security/github-advanced-security-permissions?view=azure-devops)
