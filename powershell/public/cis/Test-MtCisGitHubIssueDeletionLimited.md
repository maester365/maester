1.2.4 (L1) Ensure issue deletion is limited to specific users

CIS Benchmark: CIS GitHub Benchmark v1.2.0

Assessment Status: Manual

#### Rationale

Issues often capture defects, milestones, operational history, and security-relevant discussion. Broad issue deletion rights can disrupt development records or remove evidence of suspicious activity, so deletion should be limited to trusted users.

#### Impact

Members without the required repository or organization role will not be able to delete issues. Organizations may need a documented escalation path for legitimate issue cleanup.

#### Maester automation note

CIS marks this recommendation as Manual. By default, this Maester test uses a strict automated setting-based interpretation of CIS GH 1.2.4 and requires `members_can_delete_issues` to be `false`.

If `GitHubAllowMemberIssueDeletion` is set to literal boolean `true` in `maester-config.json`, a true value is reported as requiring manual review instead of a hard failure. That opt-in is intended for organizations that have completed and documented the CIS audit path where the organization-level issue deletion setting is enabled, requiring repository admin members to be trusted and qualified.

#### API evidence

Endpoint: `GET /orgs/{org}`

Evidence field: `members_can_delete_issues`

The test passes when `members_can_delete_issues` is `false`. With the opt-in manual-review setting enabled, a `true` value returns an Investigate/Skipped result that tells the operator to verify trusted repository administrators.

#### Permissions required

GitHub requires organization-owner visibility for full organization details. Use `Connect-MtGitHub` with a classic PAT that has `admin:org`, or a fine-grained PAT with organization Members read and Administration read permissions.

#### Remediation summary

In the organization settings, open **Member privileges** and disable the option that allows members to delete issues for the organization. If the setting remains enabled, manually verify that repository administrators are limited to trusted users and document the review.

#### Known limitations

This test verifies the organization setting only. It does not enumerate repository administrators or decide whether individual admins are trusted. When the organization-level setting is disabled, the alternate CIS audit path still requires organization owners to be trusted and qualified.

#### Related links

* [CIS GitHub Benchmark v1.2.0 - Section 1.2.4](https://www.cisecurity.org/benchmark/github)
* [GitHub REST API: Get an organization](https://docs.github.com/en/rest/orgs/orgs#get-an-organization)

<!--- Results --->
%TestResult%
