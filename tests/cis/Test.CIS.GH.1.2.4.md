1.2.4 (L1) Ensure issue deletion is limited to specific users

CIS Benchmark: CIS GitHub Benchmark v1.2.0

Assessment Status: Manual

#### Rationale

Deletion can remove development history and evidence of accidental or malicious activity. Limit issue deletion to a small, intentionally approved population of trusted and qualified users.

#### Impact

Users without the required access must ask an approved administrator or owner to handle deletion. Maintain an owner-led retirement and cleanup process.

#### Assessment

Configure the users your organization considers trusted and qualified in [GitHub deletion approvals](https://maester.dev/docs/configuration/github-deletion-policy). Maester compares those approvals with typed live evidence; it does not independently judge a person's trust or qualifications. The benchmark remains a Manual assessment, with the configured organizational judgment supporting automated Pass/Fail results.

- When `members_can_delete_issues` is `false`, every actual organization owner must be approved and the live owner count must be within `MaximumOrganizationOwners`. Its default is **3**, configurable from **1 through 3**. This is a Maester policy choice for “few”; CIS supplies no numeric owner maximum. Extra approved users who are not owners do not count.
- When `members_can_delete_issues` is `true`, declare the complete organization repository inventory. Every repository must have exactly **two effective administrators**, both approved for that repository. Extra unassigned approvals are harmless. Archived repositories are included; no exclusions are supported.

A conforming administrator baseline also requires complete custom repository-role and organization-role catalogs without additional issue-deletion permissions. Relevant additional permissions or unusable catalogs require investigation; role definitions alone do not enumerate their effective assignments. An already proven administrator-count or approval violation does not need these additive catalogs to fail. Repository-administrator status is not treated as a universal issue-deletion capability result, and no sample issue is required.

The disabled-setting result lists every validated observed owner by escaped login and numeric ID, with Approved, Not approved or Not configured status, the observed organization ID, count, maximum and completeness. Owners are collected even without approval configuration; listing a user does not approve them. Missing logins display Unavailable, and incomplete collections remain indeterminate. Unobserved approval entries are not disclosed.

Missing approvals or a repository-scope mismatch produces Investigate. Malformed configuration produces Error. Missing, unusable or incomplete required settings, identities or population evidence produces an explicit indeterminate Skipped result; request and parsing failures remain Error. Empty owner or repository results never establish absence or compliance.

The disabled-setting branch assesses the CIS-prescribed organization-owner population without evaluating compensating repository policies; it does not certify every actor's deletion capabilities. Restrictive-policy alternatives are investigated only in the enabled repository-deletion branch.

#### Permissions required

Use an organization owner with a classic PAT carrying `admin:org` and `repo` for full private-repository and organization evidence. Token scopes do not grant roles that the account does not have. Fine-grained tokens and GitHub Apps need access to all organization repositories, organization Members read and the relevant custom-role read permissions, plus repository metadata access. A successful connection or its separate Actions-policy probe does not establish evidence completeness.

Use the correct API host and host-appropriate manual token for GHE.com (`https://api.SUBDOMAIN.ghe.com`). New decisive REST reads use `2026-03-10`; connection defaults remain unchanged. Authentication limitations, partial SSO, denied access and incomplete pagination cannot establish compliance.

#### Remediation action

1. Open [your organizations](https://github.com/settings/organizations), select the organization, then review **Settings** > **Access** > **Member privileges** > **Issue deletion**. See [GitHub's guidance](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/allowing-people-to-delete-issues-in-your-organization).
2. If member deletion is disabled, review **People** filtered to **Owners**. Remove unnecessary assignments, approve the remaining trusted and qualified owners, and keep the live population within the configured maximum.
3. If member deletion is enabled, review **Settings** > **Collaborators & teams** for every repository, including organization and enterprise access. Ensure exactly two effective administrators are assigned and approve both. Review any relevant custom permissions or restrictive policies identified in the result.
4. Maintain the private approval configuration and complete inventory under your normal access-review process. Re-run the test after access or settings changes. Disabling member deletion is one supported branch; changing the checkbox alone does not complete the assessment.

#### Known limitations

Assessment covers one connected organization. It depends on an assessor-declared complete repository inventory because a token-visible inventory alone cannot prove organization-wide visibility. REST collaborator permissions represent effective base roles, including inherited grants; GraphQL `permissionSources` is not used as a complete grant model. Restrictive-policy equivalence, unresolved additional custom issue-deletion grants, and API visibility gaps require investigation.

All reads are bounded and read-only. Owner/collaborator pagination is capped at 100 pages; policy pagination is also capped. Concurrent changes can affect pagination. No deletion attempt, permission change, tenant-wide enterprise scan or automatic retry is performed. Results include observed organization and owner identities, live counts, repository names and observed unapproved administrator IDs and should be handled as tenant evidence.

#### Related links

* [CIS GitHub Benchmark](https://www.cisecurity.org/benchmark/github)
* [GitHub deletion approval configuration](https://maester.dev/docs/configuration/github-deletion-policy)
* [REST: organization members](https://docs.github.com/en/rest/orgs/members#list-organization-members)
* [REST: effective repository collaborators](https://docs.github.com/en/rest/collaborators/collaborators#list-repository-collaborators)

<!--- Results --->
%TestResult%
