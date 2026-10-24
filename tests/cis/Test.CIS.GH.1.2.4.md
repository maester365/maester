1.2.4 (L1) Ensure issue deletion is limited to specific users

CIS Benchmark: CIS GitHub Benchmark v1.2.0

Assessment Status: Manual

#### Rationale

Issues often capture defects, milestones, operational history, and security-relevant discussion. Broad issue deletion rights can disrupt development records or remove evidence of suspicious activity, so deletion should be limited to trusted users.

#### Impact

Members without the required repository or organization role will not be able to delete issues. Organizations may need a documented escalation path for legitimate issue cleanup.

#### Maester automation note

CIS marks this recommendation as Manual. This Maester test collects the organization setting evidence that maps to CIS GH 1.2.4, then reports Investigate because CIS still requires a human trust review.

When `members_can_delete_issues` is `true`, the CIS review requires exactly two trusted and qualified administrators in every repository. When it is `false`, the CIS review requires only a few organization owners, all trusted and qualified; it does not set a numeric owner limit. These are the benchmark's remaining human-review branches, not a complete authorization model derived from this flag.

#### API evidence

Endpoint: `GET /orgs/{org}`

Evidence field: `members_can_delete_issues`

An actual Boolean value is recorded as partial evidence and produces Investigate for either value. The result does not declare CIS compliance or noncompliance. A missing, null, or non-Boolean value instead produces an explicit indeterminate Skipped result.

#### Permissions required

For full organization settings, GitHub documents an organization owner using a classic PAT or OAuth token with `admin:org`. `Connect-MtGitHub` checks active organization membership; fine-grained PATs require organization Members read permission for that probe. Its separate Actions-permission probe uses organization Administration read permission, but neither that probe nor a successful connection guarantees that the required settings are returned.

Use the API host and token appropriate to the deployment. GHE.com requires an authenticated request to `api.SUBDOMAIN.ghe.com`; use a host-appropriate manual token rather than assuming the github.com device flow applies. Missing required evidence remains indeterminate on standard GHEC, Enterprise Managed Users, and GHE.com.

#### Remediation action

1. On github.com, open [your organizations](https://github.com/settings/organizations), select the organization, then open **Settings** > **Access** > **Member privileges** and review **Issue deletion**; see [GitHub's issue-deletion guidance](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/allowing-people-to-delete-issues-in-your-organization).
2. If member deletion is enabled, review **Settings** > **Collaborators & teams** in every repository. Review and adjust administrator access so that exactly two repository administrators remain, both trusted and qualified.
3. If member deletion is disabled, follow the CIS review branch by reviewing the organization's **People** page filtered to **Owners**. Review and adjust access so only a few trusted and qualified owners remain; CIS does not specify a numeric owner limit.
4. Document the population and trust review for the applicable branch. Changing the checkbox alone does not complete this assessment; disabling member deletion is not the only CIS-permitted remediation.

#### Known limitations

Only the connected organization's returned settings are assessed; this test does not enumerate every organization in an enterprise or reconstruct inherited policies. Required fields must be present and usable. Missing, null, or invalid evidence produces an explicit indeterminate Skipped result, while request and JSON parsing failures remain Error results. Missing data does not establish that a setting is disabled or that the recommendation is not applicable. Validation applies to fields available after shared JSON parsing; it is not complete raw-response schema validation.

This test verifies the organization setting only. It does not enumerate repository administrators, organization owners, or decide whether those users are trusted.

#### Related links

* [CIS GitHub Benchmark v1.2.0 - Section 1.2.4](https://www.cisecurity.org/benchmark/github)
* [GitHub REST API: Get an organization](https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/orgs?apiVersion=2026-03-10#get-an-organization)
* [GitHub: Issue deletion permissions](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/allowing-people-to-delete-issues-in-your-organization)

<!--- Results --->
%TestResult%
