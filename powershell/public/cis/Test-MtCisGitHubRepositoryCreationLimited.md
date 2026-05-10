1.2.2 (L1) Ensure repository creation is limited to specific members

CIS Benchmark: CIS GitHub Benchmark v1.2.0

Assessment Status: Manual

#### Rationale

Repository sprawl makes source ownership, visibility, and review harder to manage. Limiting who can create public and private repositories reduces the chance that organization code or data is exposed through an unmanaged repository and keeps the repository inventory easier to monitor.

#### Impact

Members who previously created repositories directly may need an owner, administrator, or approved internal process to create new repositories for them.

#### Maester automation note

CIS marks this recommendation as Manual. This Maester test automates the portion of CIS GH 1.2.2 that maps to documented GitHub REST API evidence. It should be treated as automated evidence collection for the corresponding GitHub setting, not as a claim that every possible manual review path has been fully evaluated.

This test checks the organization member privilege settings returned by `GET /orgs/{org}`.

#### API evidence

Endpoint: `GET /orgs/{org}`

Evidence fields:

- `members_can_create_public_repositories`
- `members_can_create_private_repositories`
- `members_can_create_internal_repositories` when returned, shown as informational
- `members_can_create_repositories` is displayed when returned, but is not decisive

The test passes when public and private repository creation are `false`. Internal repository creation is shown as additional enterprise/GHEC context only because the CIS GH 1.2.2 literal audit covers public and private repository creation.

#### Permissions required

GitHub requires organization-owner visibility for full organization details. Use `Connect-MtGitHub` with a classic PAT that has `admin:org`, or a fine-grained PAT with organization Members read and Administration read permissions.

#### Remediation summary

In the organization settings, open **Member privileges** and clear the public and private repository creation options for members. For GHEC organizations associated with an enterprise, review internal repository creation separately as an enterprise governance decision.

#### Known limitations

This test uses the granular repository creation fields because GitHub is replacing the older `members_allowed_repository_creation_type` behavior. If required granular fields are not returned, the test skips with a field-specific reason.

#### Related links

* [CIS GitHub Benchmark v1.2.0 - Section 1.2.2](https://www.cisecurity.org/benchmark/github)
* [GitHub REST API: Get an organization](https://docs.github.com/en/rest/orgs/orgs#get-an-organization)

<!--- Results --->
%TestResult%
