Existing Git repositories **should be** enrolled in the GitHub Secret Protection plan.

Rationale: Turning on automatic enablement only affects repositories created from that point forward. Every repository that already existed stays unenrolled until it is explicitly onboarded, so an organization can show a correctly configured plan while none of its actual code is scanned for secrets. This check assesses real coverage rather than intent.

An unenrolled repository has no secret scanning and no push protection. Secrets committed to it are neither blocked at push time nor reported afterwards.

#### Remediation action:
Enrol the existing repositories in Secret Protection. Each option shows an estimate of active committers before billing starts.

**All repositories in the organization**
1. Sign in to your organization.
2. Choose **Organization settings** > **Repos** > **Repositories**.
3. Select **Enable all**, then toggle **Secret Protection** and the subfeatures you want.
4. Select **Begin billing** to activate the plan for every existing repository in every project.

**All repositories in one project**
1. Choose **Project settings** > **Repos**, then open the **Settings** tab.
2. Select **Enable all**, toggle **Secret Protection**, then select **Begin billing**.

**A single repository**
1. Choose **Project settings** > **Repos** > **Repositories** and select the repository.
2. Toggle **Secret Protection**, then select **Begin billing**.

Note that **Enable all** is a separate action from the automatic enablement toggle covered by AZDO.1039, and must be selected independently.

**Results:**
The first table reports overall coverage. The second breaks the unenrolled repositories down by project, ordered by the size of the gap, so you can see which projects to onboard first.

This check passes only when every Git repository in the organization is enrolled. Any repository without the plan has no secret scanning and no push protection, so partial coverage is reported as a failure rather than being averaged away. An organization part way through a rollout will fail until the remaining repositories are onboarded, and the coverage ratio shows how far along it is.

This test only applies to organizations that use the separate GitHub Secret Protection and GitHub Code Security plans.

#### Related links

* [Learn - Configure GitHub Advanced Security features](https://learn.microsoft.com/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops#organization-level-onboarding)
* [Learn - Secret scanning for GitHub Advanced Security](https://learn.microsoft.com/azure/devops/repos/security/github-advanced-security-secret-scanning?view=azure-devops)
