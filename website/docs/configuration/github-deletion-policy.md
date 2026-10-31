---
title: GitHub deletion approvals
---

The GitHub deletion checks (`CIS.GH.1.2.3` and `CIS.GH.1.2.4`) compare the owners and repository administrators in your organization with the users you have approved. Your organization decides who is trusted and qualified. Maester checks their access and the number of people who have it.

Both recommendations are Manual assessments in CIS GitHub Benchmark v1.2.0. The approval configuration supplies the organizational judgment needed for Maester to assess them. The checks only read settings and access; they do not change permissions or attempt deletion.

## Configure approvals

Add `GitHubDeletionPolicy` to `GlobalSettings` in your existing `maester-config.json`. You can also put it in the supported `custom/maester-config.json` overlay. Use a separate configuration for each GitHub organization and review the approval lists through your normal access-review process. Maester does not require reviewer or expiry metadata.

Maester discovers these standard files when you do not supply `-Config` or `MAESTER_CONFIG`. Passing `-Config` explicitly bypasses automatic configuration discovery. If you use both a main file and an overlay, pass both in order, for example `-Config ./maester-config.json, ./custom/maester-config.json`. See the [run configuration reference](./run-configuration.md#where-the-configuration-comes-from) for discovery and merge rules.

```json
{
  "GlobalSettings": {
    "GitHubDeletionPolicy": {
      "ApiBaseUri": "https://api.github.com",
      "OrganizationId": "100",
      "ApprovedOwnerIds": ["101", "102", "103", "104"],
      "CompleteRepositoryInventory": true,
      "Repositories": [
        { "Id": "200", "ApprovedAdministratorIds": ["101", "105"] },
        { "Id": "201", "ApprovedAdministratorIds": ["101", "106"] }
      ]
    }
  },
  "TestSettings": [
    { "Id": "CIS.GH.1.2.3", "Parameters": { "MaximumOrganizationOwners": 3 } },
    { "Id": "CIS.GH.1.2.4", "Parameters": { "MaximumOrganizationOwners": 3 } }
  ]
}
```

The example IDs are synthetic. Use GitHub REST database IDs as **positive decimal strings**, rather than logins, node IDs, display names or JSON numbers. IDs must be unique within each list, and repository IDs must be unique across `Repositories`.

`ApiBaseUri` and `OrganizationId` must match the connection and the organization returned by GitHub. For GHE.com, use `https://api.SUBDOMAIN.ghe.com`. Unknown properties, invalid or duplicate IDs, incorrect value types, or a different host or organization produce `Error`.

Only configure the lists the checks need:

- If both member-deletion settings are disabled, `ApiBaseUri`, `OrganizationId` and `ApprovedOwnerIds` are sufficient.
- If either setting is enabled, declare the complete repository inventory and approve the administrators of each repository.
- If the settings differ, provide both owner and repository-administrator approvals.

## Find the IDs and run the checks

Use an organization owner who can see the full membership and all repositories. A classic PAT normally needs `admin:org` and `repo`; token scopes do not grant organization roles. Fine-grained PATs and [GitHub App user access tokens](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-with-a-github-app-on-behalf-of-a-user) need organization Members read permission, access to every repository and repository metadata, and the relevant custom-role read permissions for the issue-administrator check.

`Connect-MtGitHub` does not support GitHub App installation access tokens. It identifies the authenticated user through `GET /user` and checks organization membership through `GET /user/memberships/orgs/{org}`. A successful connection, including its separate Actions-permission probe, does not establish that the later assessment requests can return everything the checks need.

You can use GitHub CLI to look up the IDs. Authenticate it to the same host and intended account first, and substitute your organization and repository names:

```powershell
gh api orgs/ORGANIZATION --jq '.id'
gh api --paginate 'orgs/ORGANIZATION/members?role=admin&per_page=100' --jq '.[] | {id, login}'
gh api --paginate 'orgs/ORGANIZATION/repos?type=all&per_page=100' --jq '.[] | {id, full_name}'
gh api --paginate 'repos/ORGANIZATION/REPOSITORY/collaborators?affiliation=all&per_page=100' --jq '.[] | select(.permissions.admin == true) | {id, login}'
```

For GHE.com, add `--hostname SUBDOMAIN.ghe.com`. These optional commands only read information; they do not change access or approve users. Before adding approvals or declaring the inventory complete, compare the lists with **People** and each repository's **Manage access** view. Include access inherited from the organization and enterprise.

To run the two checks from a source checkout:

```powershell
Import-Module ./powershell/Maester.psd1 -Force
$token = Read-Host 'GitHub PAT' -AsSecureString
Connect-MtGitHub -Organization 'ORGANIZATION' -Token $token
Remove-Variable token
Invoke-MtTest -Id 'CIS.GH.1.2.3', 'CIS.GH.1.2.4' -Config ./maester-config.json
Disconnect-MtGitHub
```

For GHE.com, use a manual token for that host and pass `-ApiBaseUri 'https://api.SUBDOMAIN.ghe.com'` to `Connect-MtGitHub`. Keep the private configuration and resulting reports out of source control. Credentials do not belong in `GitHubDeletionPolicy`.

## When member deletion is disabled

When the relevant setting is `false`, Maester reads the owners with `GET /orgs/{org}/members?role=admin`. Every current owner must be in `ApprovedOwnerIds`, and the number of owners must be within `MaximumOrganizationOwners`.

The maximum defaults to **3**, configurable as a **positive integer** for each test. CIS refers to a "few" owners without specifying a number; the configured limit is your organization's interpretation. You can approve more users than the limit, but only users who are currently owners count toward it.

Maester lists the owners even if approvals have not been configured. A missing or empty approval list requires investigation regardless of the owner count. Once a nonempty approval list is configured, too many owners or an owner outside that list can establish a failure even if some other owners could not be read.

For issue deletion, GitHub's [documentation](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/allowing-people-to-delete-issues-in-your-organization) says an organization owner must enable the feature before issues can be deleted. CIS section 1.2.4 still calls for an owner review when `members_can_delete_issues` is `false`.

This part of the assessment follows that CIS owner review. It does not determine every user's deletion capabilities or check whether repository policies provide another way to meet the requirement. It needs no repository inventory, custom-role list, repository-policy read or sample issue.

## When member deletion is enabled

When the relevant setting is `true`, declare **all** organization repository IDs, including archived and unused repositories. No repository exclusions are supported. Set `CompleteRepositoryInventory` to `true` only after independently checking that the repositories visible to the token cover the whole organization.

Maester compares that list with the repositories returned by GitHub. Both lists must contain the same IDs. An empty list cannot establish that the check does not apply or that the inventory is complete.

Each repository must have **exactly two effective administrators**, both listed in its `ApprovedAdministratorIds`. Effective access includes inherited administrator permissions. Approved users who are not currently administrators do not count toward the total.

Maester reads the repository inventory even when configuration is missing. It reads administrator access only for repositories with a nonempty `ApprovedAdministratorIds` roster. Other repositories are shown as **Not assessed**, with evidence **Not collected**, and require investigation. Missing approvals, a missing or false completeness declaration, or a difference between the configured and returned repository lists prevents a pass. A confirmed failure in a configured repository can still fail the check while other repositories remain unconfigured.

### Issue deletion

Before the issue-deletion check can pass, Maester also needs complete custom repository-role and organization-role lists with no additional issue-deletion permissions. Additional permissions, inaccessible lists or definitions that Maester cannot interpret require investigation: role definitions alone do not show every user who receives those permissions.

A confirmed administrator-count or approval failure does not require these extra role requests. An administrator role alone is not proof that a user can delete every issue, and the check does not sample an issue.

### Repository deletion

If the administrator count and approvals meet the requirement, Maester does not need to read restrictive repository policies. Before failing a repository that does not meet those requirements, it checks applicable `REPOSITORY` policies, including parent policies.

An active repository-target policy requires investigation. The API information does not establish whether it provides equivalent protection or who can bypass it. Policies confirmed not to be enforcing do not prevent a result.

A confirmed failure in one repository can fail the check even when other repositories still need policy review. Those outstanding questions remain in the report. This policy review applies only when member repository deletion is enabled.

## Understand the results

| Result | Meaning |
| --- | --- |
| `Passed` | The count and approval requirements are met, and all information required for the assessment is available and usable. |
| `Failed` | The returned information proves a count or approval requirement is not met. For repository deletion, restrictive policies relevant to that confirmed failure have been checked. Policies in other repositories may still need review. |
| `Investigate` | No failure is confirmed, but approvals, the declared repository inventory, additional roles or repository policies need review. A successful request that returns no repositories also needs investigation. |
| `Skipped` | No failure is confirmed and a required setting, repository inventory or list of users is missing, invalid or incomplete. Unexpectedly empty owner or collaborator lists also produce this result, with a reason explaining what could not be determined. |
| `Error` | Configuration is invalid, or a request, timeout, JSON parsing or execution error stops the assessment. Earlier observations are retained where available, but they do not override the error. Some role or policy access denials instead require investigation, as described above. |

When required information is incomplete and no failure is confirmed, the result is `Skipped` even if approvals or policies also need review. All outstanding issues remain in the report. Uncertainty about a policy or role alone produces `Investigate`.

### Missing or conflicting data

Maester keeps usable information from incomplete responses. The following rules prevent a partial list from being treated as a complete one:

- An observed count is a minimum, not necessarily the total. Once applicable approvals are configured, too many distinct owners or administrators, or an observed user outside the approval list, can establish a failure. Fewer than two administrators establishes a failure only when the full list is available and usable. Repository-deletion failures still require the policy review described above.
- Duplicate user IDs count once and mark the list incomplete. Conflicting or unusable administrator permissions for the same ID cannot establish that the user is an administrator.
- Matching duplicate repositories count once and mark the inventory incomplete. Conflicting repository IDs, paths or ownership information exclude those repositories from assessment, regardless of response order. Other usable repositories can still establish a failure.
- A configured repository that GitHub does not return remains an unresolved inventory difference. Maester does not guess its name or access.
- A missing or empty approval list is shown as **Not configured**. It does not approve or disapprove any user and is not reported as zero unapproved users.

Administrator access comes from the REST collaborator endpoint, including inherited base permissions. The check does not use GraphQL `permissionSources` to reconstruct individual grants. Missing permissions, partial SSO access and incomplete pagination can leave the lists incomplete.

### Information shown in the report

Owner results include each observed owner's login, numeric user ID and approval status: **Approved**, **Not approved** or **Not configured**. They also show the organization ID, owner count, maximum and whether the list is complete. Logins are escaped for safe display; a missing or unusable login appears as **Unavailable** without changing the result.

Repository results include repository names, administrator counts and observed unapproved administrator IDs. Configured approval entries for users who were not observed are not listed. Approval configuration is treated as sensitive and redacted from exported configuration, but the observed organization and user information is still tenant data and should be handled accordingly.

## Collection limits

The new REST reads use API version `2026-03-10`; the connection default is unchanged. Owner, collaborator and repository inventory requests stop after 100 pages, with up to 100 items per REST page. Policy requests also stop after 100 pages and do not collect nested rules or bypass lists.

Each assessment HTTP request, including subsequent pages, has a 30-second connection/header timeout and a 30-second timeout between response-body reads. These limits do not bound the total download or assessment time. Use the existing execution `TestTimeoutSeconds` or per-test `TimeoutSeconds` setting when you need an overall deadline.

Requests are not retried automatically. Execution failures stop further requests, and concurrent access changes can affect a paginated result. Reaching a collection limit prevents a pass or a failure based only on too few observed administrators; it does not erase an already confirmed excessive count or unapproved user. Repository-deletion failures still depend on the relevant policy review.

The checks assess one connected organization. They do not scan every organization in an enterprise, change permissions or attempt deletion, and they need no sample issue or separate assessment service.

## Related links

- [GitHub: repository deletion permissions](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/setting-permissions-for-deleting-or-transferring-repositories)
- [GitHub: issue deletion permissions](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/allowing-people-to-delete-issues-in-your-organization)
- [REST: repository collaborators](https://docs.github.com/en/rest/collaborators/collaborators#list-repository-collaborators)
- [REST: custom repository roles](https://docs.github.com/en/rest/orgs/custom-roles#list-custom-repository-roles-in-an-organization)
- [REST: organization roles](https://docs.github.com/en/rest/orgs/organization-roles#get-all-organization-roles-for-an-organization)
- [GraphQL: repository rulesets](https://docs.github.com/en/graphql/reference/repos#repository)
