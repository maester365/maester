Repositories in the organization **should be** allowed to use GitHub Copilot code review.

Rationale: Copilot code review acts as an automated reviewer that comments on changed code before a human reviewer signs off, catching bugs, code quality issues, and maintainability concerns earlier. Allowing it organization wide means the review layer is available consistently rather than being blocked at the top level, which reduces the chance that changes merge with minimal review coverage.

Copilot always leaves a **Comment** review. It never approves a pull request or requests changes, so it does not satisfy required-reviewer policies and does not block merging. It complements human review and branch policies rather than replacing them.

Enablement has three scopes, and this check only assesses the first:

1. **Organization** -- a Project Collection Administrator allows repositories to use the feature.
2. **Repository** -- a repository owner enables it per repository in **Project settings** > **Repos** > **Repositories**.
3. **User** -- individual users opt in through **Preview features**, unless the administrator enables the preview for everyone.

#### Remediation action:

If the check was **skipped**, the organization has not been onboarded to the preview. Request access first:

1. [Sign up for the limited public preview](https://nam.dcv.ms/VeDNq3VRhX).
2. Once approved, the **GitHub Copilot code review** section appears in **Organization settings** > **Repos** > **Repositories**.

If the check **failed**, the organization is onboarded but the setting is off. Allow repositories to use Copilot code review:

1. Sign in to your organization as a **Project Collection Administrator**.
2. Choose **Organization settings** > **Repos** > **Repositories**.
3. Under **GitHub Copilot code review**, toggle **Allow repositories in this organization to use Copilot code review** to **On**.
4. Have repository owners enable the feature for the repositories that should use it.

Copilot code review requires an Azure subscription linked to the organization. Each completed review consumes tokens billed as GitHub AI credits through Azure Cost Management, so confirm the spend is approved and consider a budget alert before enabling it broadly.

**Results:**
The table shows whether the organization allows Copilot code review. The agent pool ID is reported when the API returns one; it is not currently documented and is shown for context only.

This check is tagged `Preview` because GitHub Copilot code review is in limited public preview and the setting is read from an undocumented data provider endpoint that can change without notice. Include it with `Invoke-Maester -IncludePreview`.

#### Related links

* [Learn - Get started with Copilot code review for pull requests](https://learn.microsoft.com/azure/devops/repos/git/copilot-code-reviews?view=azure-devops)
* [Learn - Copilot code reviews for Azure Repos (Sprint 275)](https://learn.microsoft.com/azure/devops/release-notes/2026/sprint-275-update#copilot-code-reviews-for-azure-repos-limited-public-preview)
