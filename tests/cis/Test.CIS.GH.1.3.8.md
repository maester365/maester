Organization base permissions grant members no repository access or read access only.

Base permissions apply across organization repositories. Keeping them at **None** or **Read** prevents the default from giving every member permission to change code. Members who contribute changes may need explicit repository, team, or role assignments after the default is reduced.

CIS GitHub Benchmark v1.2.0 lists section 1.3.8 as a Manual assessment. This test checks `default_repository_permission` from `GET /orgs/{org}` for the connected organization. It does not review individual repository collaborators, teams, or custom access grants.

The test passes for `none` or `read` and fails for `write` or `admin`, without regard to letter case. A missing, null, empty, unrecognized, or non-string value produces **Skipped**, with a reason explaining what could not be checked. Request or JSON parsing failures produce **Error**. Missing data does not mean the default is safe or the recommendation does not apply.

The test covers the connected organization's returned setting. It does not scan other organizations or reconstruct inherited policies. Maester checks this field after parsing the response, rather than validating the entire response schema.

#### Permissions required

Use an organization owner with a classic PAT or OAuth token carrying `admin:org` to read the full organization settings. With fine-grained PATs, the connection's membership check uses organization **Members: read**, and its separate administration check uses **Administration: read**. A successful connection does not guarantee that GitHub returns the field this test needs. See [Connect-MtGitHub](https://maester.dev/docs/commands/Connect-MtGitHub) for the connection checks.

For GHE.com, use `https://api.SUBDOMAIN.ghe.com` and a token for that host; do not assume the github.com device flow applies. The same missing-data rules apply to GHEC, Enterprise Managed Users, and GHE.com.

#### Remediation action

1. Plan explicit repository or team access for members who need to contribute after the default changes. Coordinate those grants with the relevant repository owners.
2. Open [your organizations](https://github.com/settings/organizations), select the organization, then go to **Settings** > **Access** > **Member privileges**.
3. Set **Base permissions** to **None** or **Read**, review the changes, and confirm the default-permission change.

#### Related links

* [CIS GitHub Benchmark v1.2.0 - Section 1.3.8](https://www.cisecurity.org/benchmark/github)
* [GitHub: Organization base permissions](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-user-access-to-your-organizations-repositories/managing-repository-roles/setting-base-permissions-for-an-organization)
* [GitHub REST API: Get an organization](https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/orgs?apiVersion=2026-03-10#get-an-organization)

<!--- Results --->
%TestResult%
