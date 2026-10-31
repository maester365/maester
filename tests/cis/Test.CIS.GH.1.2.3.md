Repository deletion is limited to the owners or repository administrators your organization has approved.

Deleting a repository removes code, development history, and evidence of accidental or malicious activity. Keep deletion access with a small group of trusted and qualified users, and use an approved process to retire repositories. Other users may need an owner or administrator to delete a repository for them.

CIS GitHub Benchmark v1.2.0 lists section 1.2.3 as a Manual assessment. Your organization decides which users are trusted and qualified; Maester compares your approvals with the owners and administrators returned by GitHub.

Configure `GlobalSettings.GitHubDeletionPolicy` in `maester-config.json` as described in [GitHub deletion approvals](https://maester.dev/docs/configuration/github-deletion-policy). The test follows the organization's `members_can_delete_repositories` setting:

- When member deletion is disabled, every organization owner must be approved, and the number of owners must not exceed `MaximumOrganizationOwners`. The default is **3**, configurable from **1 through 3**. This is Maester's interpretation of "few"; CIS does not specify a number.
- When member deletion is enabled, every repository must have **exactly two effective administrators**, both approved for that repository. Declare the complete repository inventory independently of what the API returns, including archived repositories. Repository exclusions are not supported.

Approved users who are not currently owners or administrators do not count toward these limits. Maester collects and reports observed access even when approvals have not been configured; seeing a user in the report does not approve that user.

When member deletion is enabled, Maester checks for policies that may further restrict deletion before confirming an administrator-count or approval failure. An active repository-target policy needs review because Maester cannot verify its effective restrictions or who can bypass it. If no other repository confirms a failure, unresolved policy questions produce **Investigate**. This extra policy review is not needed when the administrator requirements are already met, and it is not part of the owner assessment when member deletion is disabled.

A confirmed failure remains **Failed** even when other information is incomplete. When no failure is confirmed, missing, malformed, or incomplete required GitHub data produces **Skipped**. Otherwise, missing approvals or a repository list that is not confirmed as complete or does not match GitHub require **Investigate**. Invalid configuration, failed requests, and JSON parsing errors produce **Error**, even if earlier observations suggest a failure. The test cannot pass with incomplete information.

Use an organization owner and a token that can read all required settings, users, and repositories. The [approval guide](https://maester.dev/docs/configuration/github-deletion-policy) lists the permissions and GHE.com connection requirements and explains how incomplete results are assessed. The check reads only the connected organization and does not attempt deletion or change permissions. Reports contain organization, user, and repository information and should be handled as sensitive assessment data.

#### Remediation action

1. On the connected GitHub web host (`github.com` or your enterprise's `SUBDOMAIN.ghe.com`), open **Your organizations**, select the organization, then go to **Settings** > **Access** > **Member privileges** > **Repository deletion and transfer**.
2. If member deletion is disabled, review **People** filtered to **Owners**. Remove unnecessary assignments, approve the remaining trusted and qualified owners, and keep the number of owners within the configured maximum.
3. If member deletion is enabled, review **Settings** > **Collaborators & teams** for every repository, including access inherited from the organization or enterprise. Ensure exactly two effective administrators are assigned and approve both. Review any restrictive policies identified in the result.
4. Update the approval configuration after access changes. If member deletion is enabled, also update the complete repository inventory. Then run the test again. Changing the member-deletion setting alone does not complete the assessment.

#### Related links

* [CIS GitHub Benchmark v1.2.0 - Section 1.2.3](https://www.cisecurity.org/benchmark/github)
* [GitHub: Repository deletion permissions](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/setting-permissions-for-deleting-or-transferring-repositories)
* [GitHub deletion approval configuration](https://maester.dev/docs/configuration/github-deletion-policy)
* [REST: Organization members](https://docs.github.com/en/rest/orgs/members#list-organization-members)
* [REST: Effective repository collaborators](https://docs.github.com/en/rest/collaborators/collaborators#list-repository-collaborators)

<!--- Results --->
%TestResult%
