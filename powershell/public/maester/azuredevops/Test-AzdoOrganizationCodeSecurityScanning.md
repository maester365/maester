Repositories with the GitHub Code Security plan enabled **should** have dependency alerts and CodeQL alerts turned on.

Rationale: The Code Security plan is what grants access to dependency scanning and code scanning, but the individual scanning features still have to be turned on. A repository that is enrolled in the plan with both features off is billed for Code Security while producing no findings, which reads as a clean security posture when nothing has actually been scanned.

#### Remediation action:
Enable the scanning features for the affected repositories.
1. Sign in to your organization.
2. Choose **Organization settings**.
3. Select **Repositories**.
4. Next to **Code Security plan**, select **Options**.
5. Check **Dependency alerts** and **CodeQL alerts**, then select **Apply**.

Scanning features can also be set per repository under **Project settings** > **Repos** > **Repositories** > select the repository > **Options**.

**Results:**
The first table states the scope being assessed: how many repositories are enrolled in Code Security, how many of those are fully scanned, and how many are not enrolled in Code Security. Only the enrolled repositories are assessed, so a pass here does not mean the organization is covered. Enrolment is reported by AZDO.1043.

A repository counted as not enrolled in Code Security may still be enrolled in Secret Protection, since the two plans are purchased and enabled independently. It produces no dependency or code scanning alerts either way.

When repositories are missing a scanning feature, a second table counts how many are missing dependency alerts and how many are missing CodeQL alerts, and a third groups the affected repositories by project so you can see where to start.

This test only applies to organizations that use the separate GitHub Secret Protection and GitHub Code Security plans, and is skipped when no repository has the plan enabled.

#### Related links

* [Learn - Set up code scanning](https://learn.microsoft.com/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops#set-up-code-scanning)
* [Learn - Set up dependency scanning](https://learn.microsoft.com/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops#set-up-dependency-scanning)
