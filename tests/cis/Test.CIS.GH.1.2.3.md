1.2.3 (L1) Ensure repository deletion is limited to specific users

CIS Benchmark: CIS GitHub Benchmark v1.2.0

Assessment Status: Manual

#### Rationale

Deleting repositories can cause major source loss, break delivery workflows, and hide malicious or accidental activity. Repository deletion should therefore be limited to a small set of trusted people whose access is reviewed intentionally.

#### Impact

Members without the required repository or organization role will not be able to delete or transfer repositories. Teams may need a documented owner-led process for repository retirement.

#### Maester automation note

CIS marks this recommendation as Manual. This Maester test collects the organization setting evidence that maps to CIS GH 1.2.3, then reports Investigate because CIS still requires a human trust review.

When `members_can_delete_repositories` is `true`, CIS requires verifying that repository admin members are trusted and qualified. When it is `false`, CIS still requires verifying that organization owners are trusted and qualified.

#### API evidence

Endpoint: `GET /orgs/{org}`

Evidence field: `members_can_delete_repositories`

When this field is returned, the test records the actual value and returns Investigate so the remaining CIS manual review path is visible in Maester results.

#### Permissions required

GitHub requires organization-owner visibility for full organization details. Use `Connect-MtGitHub` with a classic PAT that has `admin:org`, or a fine-grained PAT with organization Members read and Administration read permissions.

#### Remediation summary

In the organization settings, open **Member privileges** and disable the option that allows members to delete or transfer repositories for the organization. If the setting remains enabled, manually verify that repository administrators are limited to trusted users and document the review. If the setting is disabled, verify that organization owners are limited to trusted users and document the review.

#### Known limitations

This test verifies the organization setting only. It does not enumerate repository administrators, organization owners, or decide whether those users are trusted.

#### Related links

* [CIS GitHub Benchmark v1.2.0 - Section 1.2.3](https://www.cisecurity.org/benchmark/github)
* [GitHub REST API: Get an organization](https://docs.github.com/en/rest/orgs/orgs#get-an-organization)

<!--- Results --->
%TestResult%
