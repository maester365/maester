1.3.2 (L1) Ensure team creation is limited to specific members

CIS Benchmark: CIS GitHub Benchmark v1.2.0

Assessment Status: Manual

#### Rationale

Teams can inherit access and quickly become part of the organization's permission model. Restricting team creation helps prevent shadow teams, accidental privilege expansion, and unnecessary organizational clutter.

#### Impact

Members who previously created teams directly may need an owner, administrator, or approved access-management process to create new teams.

#### Maester automation note

CIS marks this recommendation as Manual. This Maester test automates the portion of CIS GH 1.3.2 that maps to documented GitHub REST API evidence. It should be treated as automated evidence collection for the corresponding GitHub setting, not as a claim that every possible manual review path has been fully evaluated.

#### API evidence

Endpoint: `GET /orgs/{org}`

Evidence field: `members_can_create_teams`

The test passes when `members_can_create_teams` is `false`.

#### Permissions required

GitHub requires organization-owner visibility for full organization details. Use `Connect-MtGitHub` with a classic PAT that has `admin:org`, or a fine-grained PAT with organization Members read and Administration read permissions.

#### Remediation summary

In the organization settings, open **Member privileges** and disable **Allow members to create teams**.

#### Known limitations

This test verifies the organization-level team creation setting. It does not review custom operational processes for who may request or approve new teams.

#### Related links

* [CIS GitHub Benchmark v1.2.0 - Section 1.3.2](https://www.cisecurity.org/benchmark/github)
* [GitHub REST API: Get an organization](https://docs.github.com/en/rest/orgs/orgs#get-an-organization)

<!--- Results --->
%TestResult%
