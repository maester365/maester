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

The field must be a Boolean value. The test passes when it is `false` and fails when it is `true`.

#### Permissions required

For full organization settings, GitHub documents an organization owner using a classic PAT or OAuth token with `admin:org`. `Connect-MtGitHub` checks active organization membership; fine-grained PATs require organization Members read permission for that probe. Its separate Actions-permission probe uses organization Administration read permission, but neither that probe nor a successful connection guarantees that the required settings are returned.

Use the API host and token appropriate to the deployment. GHE.com requires an authenticated request to `api.SUBDOMAIN.ghe.com`; use a host-appropriate manual token rather than assuming the github.com device flow applies. Missing required evidence remains indeterminate on standard GHEC, Enterprise Managed Users, and GHE.com.

#### Remediation action

1. On github.com, open [your organizations](https://github.com/settings/organizations), select the organization, then open **Settings** > **Access** > **Member privileges**; see [GitHub's team-creation guidance](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/setting-team-creation-permissions-in-your-organization).
2. Under **Team creation rules**, clear **Allow members to create teams**.
3. Save the change and use the organization's approved process for new-team requests.

#### Known limitations

Only the connected organization's returned settings are assessed; this test does not enumerate every organization in an enterprise or reconstruct inherited policies. Required fields must be present and usable. Missing, null, or invalid evidence produces an explicit indeterminate Skipped result, while request and JSON parsing failures remain Error results. Missing data does not establish that a setting is disabled or that the recommendation is not applicable. Validation applies to fields available after shared JSON parsing; it is not complete raw-response schema validation.

This test verifies the organization-level team creation setting. It does not review custom operational processes for who may request or approve new teams.

#### Related links

* [CIS GitHub Benchmark v1.2.0 - Section 1.3.2](https://www.cisecurity.org/benchmark/github)
* [GitHub REST API: Get an organization](https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/orgs?apiVersion=2026-03-10#get-an-organization)
* [GitHub: Team creation permissions](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/setting-team-creation-permissions-in-your-organization)

<!--- Results --->
%TestResult%
