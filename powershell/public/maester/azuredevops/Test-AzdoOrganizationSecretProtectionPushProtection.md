Repositories with the GitHub Secret Protection plan enabled **should** block pushes that contain secrets.

Rationale: Secret alerts tell you a secret was committed, which means the secret is already in the repository history and must be rotated. Push protection stops the commit at push time, preventing the exposure instead of reporting it. A repository that is licensed for Secret Protection but has push protection turned off pays for the plan while keeping the weaker of the two controls.

Push protection only evaluates pushes that occur after the feature is enabled. Existing secrets in history are found by repository secret scanning, which is always on for enrolled repositories.

#### Remediation action:
Enable push protection for the affected repositories.
1. Sign in to your organization.
2. Choose **Organization settings**.
3. Select **Repositories**.
4. Next to **Secret Protection plan**, select **Options**.
5. Check **Push protections**, then select **Apply**.

Push protection can also be set per repository under **Project settings** > **Repos** > **Repositories** > select the repository > **Options**.

**Results:**
The first table states the scope being assessed: how many repositories are enrolled in Secret Protection, how many of those block pushes, and how many are not enrolled in Secret Protection. Only the enrolled repositories are assessed, so a pass here does not mean the organization is covered. Enrolment is reported by AZDO.1040.

A repository counted as not enrolled in Secret Protection may still be enrolled in Code Security, since the two plans are purchased and enabled independently. It has no secret scanning and no push protection either way.

When enrolled repositories do not block pushes, a second table groups them by project so you can see where to start.

**Secret alerts** is always available for enrolled repositories and cannot be turned off, so it is not assessed by this test. It has no corresponding property in the API.

This test only applies to organizations that use the separate GitHub Secret Protection and GitHub Code Security plans, and is skipped when no repository has the plan enabled.

#### Related links

* [Learn - Set up secret scanning](https://learn.microsoft.com/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops#set-up-secret-scanning)
* [Learn - Secret scanning for GitHub Advanced Security](https://learn.microsoft.com/azure/devops/repos/security/github-advanced-security-secret-scanning?view=azure-devops)
