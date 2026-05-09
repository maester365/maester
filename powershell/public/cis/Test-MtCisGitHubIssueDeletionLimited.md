1.2.4 (L1) Ensure issue deletion is limited to specific users

CIS Benchmark: CIS GitHub Benchmark v1.2.0

Assessment Status: Manual

#### Maester automation note

CIS marks this recommendation as Manual. This Maester test automates the portion of the CIS audit procedure that maps to documented GitHub REST API evidence. It should be treated as automated evidence collection for the corresponding GitHub setting, not as a claim that every possible manual review path for the CIS recommendation has been fully evaluated.

This test implements the strict automated setting-based interpretation of CIS.GH.1.2.4. CIS also describes a manual trust-review path when issue deletion by members is enabled; this test does not evaluate that manual trust review.

#### API evidence

Endpoint: `GET /orgs/{org}`

Evidence field: `members_can_delete_issues`

The test passes when `members_can_delete_issues` is `false`.

#### Permissions required

GitHub requires organization-owner visibility for full organization details. Use `Connect-MtGitHub` with a classic PAT that has `admin:org`, or a fine-grained PAT with organization Members read and Administration read permissions.

#### Remediation summary

In the organization settings, open **Member privileges** and disable the option that allows members to delete issues for the organization.

#### Known limitations

This test verifies the organization setting only. It does not enumerate repository administrators or decide whether individual admins are trusted.

<!--- Results --->
%TestResult%
