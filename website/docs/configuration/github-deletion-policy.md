---
title: GitHub deletion approvals
---

The GitHub deletion checks (`CIS.GH.1.2.3` and `CIS.GH.1.2.4`) compare live access with your organization's approved users. Your configuration supplies the human judgment that those users are trusted and qualified; Maester checks the applicable population and count. It never grants access or attempts deletion.

Put `GitHubDeletionPolicy` in `GlobalSettings` in a private configuration under the ignored `TestResults/` folder (for example `TestResults/github-deletion.config.json`) or outside the checkout, and pass it explicitly with `-Config`. Use a separate configuration for each GitHub organization. Keep approval lists under your normal access-review process; no expiry or reviewer metadata is required.

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

All example IDs are synthetic. Use stable GitHub REST database IDs as **positive decimal strings**, not logins, node IDs, display names or JSON numbers. IDs must be unique within each list; repository IDs must also be unique. `ApiBaseUri` and `OrganizationId` must match the connection and the live organization. For GHE.com, use `https://api.SUBDOMAIN.ghe.com`. Unknown properties, invalid IDs, wrong value types or a target mismatch produce Error.

Only configure the fields needed by your chosen branch. If both member-deletion settings are disabled, `ApiBaseUri`, `OrganizationId` and `ApprovedOwnerIds` are sufficient. Configure both branch populations if the two settings differ.

### Look up IDs and run the checks

Review IDs with an organization owner who can see the complete membership and repository populations. If you use GitHub CLI, authenticate it to the same host and intended account before running these optional read commands. Substitute your organization name; the commands do not change access or generate an approval roster automatically.

```powershell
gh api orgs/ORGANIZATION --jq '.id'
gh api --paginate 'orgs/ORGANIZATION/members?role=admin&per_page=100' --jq '.[] | {id, login}'
gh api --paginate 'orgs/ORGANIZATION/repos?type=all&per_page=100' --jq '.[] | {id, full_name}'
gh api --paginate 'repos/ORGANIZATION/REPOSITORY/collaborators?affiliation=all&per_page=100' --jq '.[] | select(.permissions.admin == true) | {id, login}'
```

For GHE.com, add the matching GitHub CLI `--hostname SUBDOMAIN.ghe.com` option. Independently compare the populations with **People** and each repository's **Manage access** view, including organization and enterprise access, before approving users or declaring inventory completeness.

Use an organization owner and a token with sufficient visibility. A classic PAT normally needs `admin:org` and `repo`; token scopes do not confer account roles. Fine-grained or App authentication needs organization Members read, access to every repository, and relevant custom-role read permissions for the issue-administrator branch. A successful connection does not prove these later reads are complete.

Run only these two checks from the source checkout using your private configuration:

```powershell
Import-Module ./powershell/Maester.psd1 -Force
$token = Read-Host 'GitHub PAT' -AsSecureString
Connect-MtGitHub -Organization 'ORGANIZATION' -Token $token
Remove-Variable token
Invoke-MtTest -Id 'CIS.GH.1.2.3', 'CIS.GH.1.2.4' -Config ./TestResults/github-deletion.config.json
Disconnect-MtGitHub
```

For GHE.com, also pass the matching `-ApiBaseUri 'https://api.SUBDOMAIN.ghe.com'` to `Connect-MtGitHub`. Keep the private configuration and resulting reports out of source control.

### Organization-owner branch

When the relevant member-deletion setting is `false`, Maester collects the organization's owners with `GET /orgs/{org}/members?role=admin`. Every actual owner must be on `ApprovedOwnerIds`, and the number of distinct actual owners must not exceed `MaximumOrganizationOwners`.

The maximum defaults to **3**, and each test accepts **1 through 3**. This is a documented Maester policy choice for CIS's undefined word “few”; it is not a number supplied by CIS. Approval lists may contain more than three users: approved users who are not currently owners do not count toward the limit. A missing or empty owner approval list produces Investigate.

This branch assesses the CIS-prescribed organization-owner population without evaluating compensating repository policies; it is not an exhaustive certification of actor capabilities. It does not require repository inventories, custom-role catalogs, policies, or a sample issue. Restrictive-policy alternatives are investigated only in the enabled repository-deletion branch.

### Repository-administrator branch

When the relevant setting is `true`, declare **all** organization repository IDs, including archived and unused repositories. `CompleteRepositoryInventory: true` states that you have independently checked that the token-visible inventory covers the whole organization. Maester reconciles the declaration against the live inventory and requires matching IDs in both directions. No repository exclusions are supported. An empty inventory does not establish applicability or completeness.

For every repository, the complete REST collaborator population must contain **exactly two effective administrators**, both on that repository's `ApprovedAdministratorIds`. The collaborator endpoint includes inherited base-administrator permissions; GraphQL `permissionSources` is not used to reconstruct grants. Extra approved users who are not actual administrators do not fail the test. Missing or empty approval rosters require investigation.

For issue deletion, an otherwise conforming administrator baseline also requires complete custom repository-role and organization-role catalogs without additional issue-deletion permissions. Relevant custom permissions, inaccessible catalogs, unknown semantics or malformed definitions require investigation because their effective assignment population is unresolved. An already proven administrator-count or approval violation can fail without collecting these additive permissions.

For repository deletion, a baseline that already meets the count and approval criteria needs no restrictive-policy query. Before an apparent violation becomes Failed, Maester checks applicable parent and repository `REPOSITORY` policies. An active repository-target policy needs investigation; public API evidence does not establish stronger-policy equivalence or effective bypass membership. Complete evidence of non-enforcing policies does not block the verdict. A confirmed violation in one repository can fail the overall check even if other repositories still need policy review; those gaps remain in the result.

### Outcomes and collection limits

| Evidence | Result |
| --- | --- |
| Applicable count and approval criteria satisfied, all required evidence usable | Passed |
| Applicable count or approval criterion disproved, without an unresolved relevant restrictive alternative | Failed |
| Missing approvals, scope reconciliation gap, or unresolved relevant custom role/policy | Investigate |
| Required setting, identity, owner or collaborator evidence missing, malformed, unexpectedly empty or incomplete | Skipped with an explicit indeterminate reason |
| Invalid configuration, HTTP failure or JSON parsing/execution failure | Error; role/policy access denials are recorded as unresolved visibility where applicable |

New REST reads use API version `2026-03-10`; the existing connection default stays unchanged. Owner and collaborator pagination stops at 100 pages of 100 items; repository inventory uses the shared bounded collector. Policy pagination stops at 100 pages, with no nested rule or bypass collection. Any truncation prevents an unsupported Pass or failure based on missing restrictive evidence. There are no automatic retries. Concurrent access changes can still affect a paginated observation.

The configuration is marked sensitive and redacted from exported configuration. Results report live counts, repository names and observed unapproved user IDs, so handle reports as tenant evidence. Credentials never belong in this object. No sample issue, deletion attempt, permission change or separate assessment service is needed.

### Related references

- [GitHub: repository deletion permissions](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/setting-permissions-for-deleting-or-transferring-repositories)
- [GitHub: issue deletion permissions](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/allowing-people-to-delete-issues-in-your-organization)
- [REST: repository collaborators](https://docs.github.com/en/rest/collaborators/collaborators#list-repository-collaborators)
- [REST: custom repository roles](https://docs.github.com/en/rest/orgs/custom-roles#list-custom-repository-roles-in-an-organization)
- [REST: organization roles](https://docs.github.com/en/rest/orgs/organization-roles#get-all-organization-roles-for-an-organization)
- [GraphQL: repository rulesets](https://docs.github.com/en/graphql/reference/repos#repository)
