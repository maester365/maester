1.2.3 (L1) Ensure repository deletion is limited to specific users

CIS Benchmark: CIS GitHub Benchmark v1.2.0

Assessment Status: Manual

#### Maester automation note

CIS marks this recommendation as Manual. This Maester test automates the portion of the CIS audit procedure that maps to documented GitHub REST API evidence. It should be treated as automated evidence collection for the corresponding GitHub setting, not as a claim that every possible manual review path for the CIS recommendation has been fully evaluated.

This test implements the strict automated setting-based interpretation of CIS.GH.1.2.3. CIS also describes a manual trust-review path when repository deletion by members is enabled; this test does not evaluate that manual trust review.

#### API evidence

Endpoint: `GET /orgs/{org}`

Evidence field: `members_can_delete_repositories`

The test passes when `members_can_delete_repositories` is `false`.

#### Permissions required

GitHub requires organization-owner visibility for full organization details. Use `Connect-MtGitHub` with a classic PAT that has `admin:org`, or a fine-grained PAT with organization Members read and Administration read permissions.

#### Remediation summary

In the organization settings, open **Member privileges** and disable the option that allows members to delete or transfer repositories for the organization. Alternatively, if the setting remains enabled, manually verify that repository administrators are limited to trusted users as described by CIS.

#### Known limitations

This test verifies the organization setting only. It does not enumerate repository administrators or decide whether individual admins are trusted.

#### Related links

* [CIS GitHub Benchmark v1.2.0 - Page 63](https://www.cisecurity.org/benchmark/github)
* [GitHub REST API: Get an organization](https://docs.github.com/en/rest/orgs/orgs#get-an-organization)

<!--- Results --->
%TestResult%
