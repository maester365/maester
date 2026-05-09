1.3.8 (L1) Ensure strict base permissions are set for repositories

CIS Benchmark: CIS GitHub Benchmark v1.2.0

Assessment Status: Manual

#### Maester automation note

CIS marks this recommendation as Manual. This Maester test automates the portion of the CIS audit procedure that maps to documented GitHub REST API evidence. It should be treated as automated evidence collection for the corresponding GitHub setting, not as a claim that every possible manual review path for the CIS recommendation has been fully evaluated.

#### API evidence

Endpoint: `GET /orgs/{org}`

Evidence field: `default_repository_permission`

The test passes when `default_repository_permission` is `none` or `read`. It fails when the value is `write` or `admin`.

#### Permissions required

GitHub requires organization-owner visibility for full organization details. Use `Connect-MtGitHub` with a classic PAT that has `admin:org`, or a fine-grained PAT with organization Members read and Administration read permissions.

#### Remediation summary

In the organization settings, open **Member privileges** and set **Base permissions** to **None** or **Read**.

#### Known limitations

This test verifies the organization default repository permission only. It does not review per-repository collaborators, teams, or custom access grants.

<!--- Results --->
%TestResult%
