1.2.2 (L1) Ensure repository creation is limited to specific members

CIS Benchmark: CIS GitHub Benchmark v1.2.0

Assessment Status: Manual

#### Maester automation note

CIS marks this recommendation as Manual. This Maester test automates the portion of the CIS audit procedure that maps to documented GitHub REST API evidence. It should be treated as automated evidence collection for the corresponding GitHub setting, not as a claim that every possible manual review path for the CIS recommendation has been fully evaluated.

This test checks the organization member privilege settings returned by `GET /orgs/{org}`.

#### API evidence

Endpoint: `GET /orgs/{org}`

Evidence fields:

- `members_can_create_public_repositories`
- `members_can_create_private_repositories`
- `members_can_create_internal_repositories` when returned
- `members_can_create_repositories` is displayed when returned, but is not decisive

The test passes when public and private repository creation are `false`, and internal repository creation is also `false` when the API returns that field.

The internal repository check is an intentional GHEC / GHEC EMU enterprise-associated extension beyond the literal CIS audit text, which calls out public and private repository creation. An organization with public and private creation disabled but internal creation enabled will fail this Maester test even though it may satisfy the literal CIS checkbox wording.

#### Permissions required

GitHub requires organization-owner visibility for full organization details. Use `Connect-MtGitHub` with a classic PAT that has `admin:org`, or a fine-grained PAT with organization Members read and Administration read permissions.

#### Remediation summary

In the organization settings, open **Member privileges** and clear the repository creation options for members. For GHEC organizations associated with an enterprise, also ensure internal repository creation is not allowed for members.

#### Known limitations

This test uses the granular repository creation fields because GitHub is replacing the older `members_allowed_repository_creation_type` behavior. If required granular fields are not returned, the test skips with a field-specific reason.

#### Related links

* [CIS GitHub Benchmark v1.2.0 - Page 61](https://www.cisecurity.org/benchmark/github)
* [GitHub REST API: Get an organization](https://docs.github.com/en/rest/orgs/orgs#get-an-organization)

<!--- Results --->
%TestResult%
