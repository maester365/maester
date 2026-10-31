Organization members cannot create teams.

Teams can grant access to organization repositories. Restricting who can create them helps prevent unplanned access and makes the organization's permissions easier to manage. Members who need a new team may need an owner, administrator, or approved access-management process to create it.

CIS GitHub Benchmark v1.2.0 lists section 1.3.2 as a Manual assessment. This test checks `members_can_create_teams` from `GET /orgs/{org}` for the connected organization. It does not review the organization's process for requesting or approving new teams.

The test passes when the field is Boolean `false` and fails when it is Boolean `true`. A missing, null, or non-Boolean value produces **Skipped**, with a reason explaining what could not be checked. Request or JSON parsing failures produce **Error**. Missing data does not mean team creation is disabled or the recommendation does not apply.

The test covers the connected organization's returned setting. It does not scan other organizations or reconstruct inherited policies. Maester checks this field after parsing the response, rather than validating the entire response schema.

#### Permissions required

Use an organization owner with a classic PAT or OAuth token carrying `admin:org` to read the full organization settings. With fine-grained PATs, the connection's membership check uses organization **Members: read**, and its separate administration check uses **Administration: read**. A successful connection does not guarantee that GitHub returns the field this test needs. See [Connect-MtGitHub](https://maester.dev/docs/commands/Connect-MtGitHub) for the connection checks.

For GHE.com, use `https://api.SUBDOMAIN.ghe.com` and a token for that host; do not assume the github.com device flow applies. The same missing-data rules apply to GHEC, Enterprise Managed Users, and GHE.com.

#### Remediation action

1. On the connected GitHub web host (`github.com` or your enterprise's `SUBDOMAIN.ghe.com`), open **Your organizations**, select the organization, then go to **Settings** > **Access** > **Member privileges**.
2. Under **Team creation rules**, clear **Allow members to create teams**.
3. Save the change and use the organization's approved process for new-team requests.

#### Related links

* [CIS GitHub Benchmark v1.2.0 - Section 1.3.2](https://www.cisecurity.org/benchmark/github)
* [GitHub: Team creation permissions](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/setting-team-creation-permissions-in-your-organization)
* [GitHub REST API: Get an organization](https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/orgs?apiVersion=2026-03-10#get-an-organization)

<!--- Results --->
%TestResult%
