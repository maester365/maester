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
- `members_allowed_repository_creation_type` is displayed when returned, but is not decisive

Both decisive fields must be Boolean values. The test passes when both are `false` and fails when either is `true`. Internal repository creation is shown as additional enterprise/GHEC context only because the CIS GH 1.2.2 literal audit covers public and private repository creation.

#### Permissions required

For full organization settings, GitHub documents an organization owner using a classic PAT or OAuth token with `admin:org`. `Connect-MtGitHub` checks active organization membership; fine-grained PATs require organization Members read permission for that probe. Its separate Actions-permission probe uses organization Administration read permission, but neither that probe nor a successful connection guarantees that the required settings are returned.

Use the API host and token appropriate to the deployment. GHE.com requires an authenticated request to `api.SUBDOMAIN.ghe.com`; use a host-appropriate manual token rather than assuming the github.com device flow applies. Missing required evidence remains indeterminate on standard GHEC, Enterprise Managed Users, and GHE.com.

#### Remediation action

1. On github.com, open [your organizations](https://github.com/settings/organizations), select the organization, then open **Settings** > **Access** > **Member privileges**; see [GitHub's repository-creation guidance](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/restricting-repository-creation-in-your-organization).
2. Clear the public and private repository-creation options for members, then save the changes. If an enterprise policy controls the options, coordinate the change with an enterprise owner.
3. Review internal repository creation separately as an enterprise governance decision; its returned flag does not decide this check.

#### Known limitations

Only the connected organization's returned settings are assessed; this test does not enumerate every organization in an enterprise or reconstruct inherited policies. Required fields must be present and usable. Missing, null, or invalid evidence produces an explicit indeterminate Skipped result, while request and JSON parsing failures remain Error results. Missing data does not establish that a setting is disabled or that the recommendation is not applicable. Validation applies to fields available after shared JSON parsing; it is not complete raw-response schema validation.

This test uses the granular repository creation fields because GitHub is replacing the legacy `members_allowed_repository_creation_type` umbrella field. That umbrella value is displayed when returned, but is not decisive. If required granular fields are not returned, the test skips with a field-specific reason.

#### Related links

* [CIS GitHub Benchmark v1.2.0 - Section 1.2.2](https://www.cisecurity.org/benchmark/github)
* [GitHub REST API: Get an organization](https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/orgs?apiVersion=2026-03-10#get-an-organization)
* [GitHub: Restricting repository creation](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/restricting-repository-creation-in-your-organization)

<!--- Results --->
%TestResult%
