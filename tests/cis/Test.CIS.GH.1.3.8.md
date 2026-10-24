1.3.8 (L1) Ensure strict base permissions are set for repositories

CIS Benchmark: CIS GitHub Benchmark v1.2.0

Assessment Status: Manual

#### Rationale

Base permissions apply broadly across organization repositories. Keeping the default at none or read follows least privilege and lowers the chance that every member can change code where they do not have a specific business need.

#### Impact

Some members may lose default write access and require explicit repository, team, or role assignments before they can contribute changes.

#### Maester automation note

CIS marks this recommendation as Manual. This Maester test automates the portion of CIS GH 1.3.8 that maps to documented GitHub REST API evidence. It should be treated as automated evidence collection for the corresponding GitHub setting, not as a claim that every possible manual review path has been fully evaluated.

#### API evidence

Endpoint: `GET /orgs/{org}`

Evidence field: `default_repository_permission`

The field must be a recognized string value. The test passes for `none` or `read` and fails for `write` or `admin`, retaining case-insensitive matching. Null, empty, unrecognized, or non-string values are indeterminate rather than evidence of excessive access.

#### Permissions required

For full organization settings, GitHub documents an organization owner using a classic PAT or OAuth token with `admin:org`. `Connect-MtGitHub` checks active organization membership; fine-grained PATs require organization Members read permission for that probe. Its separate Actions-permission probe uses organization Administration read permission, but neither that probe nor a successful connection guarantees that the required settings are returned.

Use the API host and token appropriate to the deployment. GHE.com requires an authenticated request to `api.SUBDOMAIN.ghe.com`; use a host-appropriate manual token rather than assuming the github.com device flow applies. Missing required evidence remains indeterminate on standard GHEC, Enterprise Managed Users, and GHE.com.

#### Remediation action

1. Plan explicit repository or team access for members who need to contribute after the default changes. Coordinate those grants with the relevant repository owners.
2. On github.com, open [your organizations](https://github.com/settings/organizations), select the organization, then open **Settings** > **Access** > **Member privileges**; see [GitHub's base-permission guidance](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-user-access-to-your-organizations-repositories/managing-repository-roles/setting-base-permissions-for-an-organization).
3. Set **Base permissions** to **None** or **Read**, review the changes, and confirm the default-permission change.

#### Known limitations

Only the connected organization's returned settings are assessed; this test does not enumerate every organization in an enterprise or reconstruct inherited policies. Required fields must be present and usable. Missing, null, or invalid evidence produces an explicit indeterminate Skipped result, while request and JSON parsing failures remain Error results. Missing data does not establish that a setting is disabled or that the recommendation is not applicable. Validation applies to fields available after shared JSON parsing; it is not complete raw-response schema validation.

This test verifies the organization default repository permission only. It does not review per-repository collaborators, teams, or custom access grants.

#### Related links

* [CIS GitHub Benchmark v1.2.0 - Section 1.3.8](https://www.cisecurity.org/benchmark/github)
* [GitHub REST API: Get an organization](https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/orgs?apiVersion=2026-03-10#get-an-organization)
* [GitHub: Organization base permissions](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-user-access-to-your-organizations-repositories/managing-repository-roles/setting-base-permissions-for-an-organization)

<!--- Results --->
%TestResult%
