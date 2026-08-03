The GitHub Code Security plan **should be** automatically enabled on newly created Git repositories.

Rationale: Code Security provides dependency alerts for vulnerabilities in open source dependencies, CodeQL scanning to detect vulnerabilities directly in your code, ingestion of findings from third-party scanning tools, and a security overview of your organization's risk. When automatic enablement is off, every new repository starts unscanned and has to be onboarded manually, so coverage silently degrades as the organization grows.

#### Remediation action:
Enable automatic enrollment of the Code Security plan for new repositories.
1. Sign in to your organization.
2. Choose **Organization settings**.
3. Select **Repositories**.
4. Toggle **Code Security plan** to on, then select **Begin billing** to activate the plan.
5. Optionally select **Options** to also enable dependency scanning and CodeQL default setup for the repositories that are enrolled.

**Results:**
With automatic enablement on, any Git repository created in the organization from that point on has Code Security enabled at creation.

This setting has no effect on repositories that already exist. They must be enrolled separately using **Enable all**, which is assessed by AZDO.1043. A passing result here does not mean the organization is covered.

This test only applies to organizations that use the separate GitHub Secret Protection and GitHub Code Security plans. Organizations on the bundled GitHub Advanced Security for Azure DevOps SKU are skipped, because automatic enablement for the bundled SKU is reported by AZDO.1026 instead.

#### Related links

* [Learn - Configure GitHub Advanced Security features](https://learn.microsoft.com/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops#organization-level-onboarding)
* [Learn - Manage Advanced Security permissions](https://learn.microsoft.com/azure/devops/repos/security/github-advanced-security-permissions?view=azure-devops)
