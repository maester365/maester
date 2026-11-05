The organization requires members and outside collaborators to use two-factor authentication.

Organization two-factor authentication reduces the risk that an attacker uses a stolen password to access code through a member or outside collaborator account. Enabling it can remove or block access for people who have not enrolled, so coordinate enrollment, recovery, and a staged rollout with affected contributors.

CIS GitHub Benchmark v1.2.0 lists section 1.3.5 as a Manual assessment (physical PDF pages 84–85; printed pages 83–84). This test reads `two_factor_requirement_enabled` from `GET /orgs/{org}` with REST version `2026-03-10`.

For personal-account organizations, the test passes when the field is Boolean `true` and fails when it is Boolean `false`. A missing, null, or non-Boolean value produces **Skipped**, with a reason explaining what could not be checked. Request or JSON parsing failures produce **Error**.

Set `GitHubAccountModel` to `PersonalAccounts` only for organizations that use personal accounts. The default `Unknown` produces **Skipped**. Enterprise Managed Users, including GHE.com, use an external identity provider for MFA and remain **Skipped** in this GitHub-only check, even when GitHub returns its organization 2FA field. Provisioning, SSO, individual enrollment, and a successful connection do not establish the IdP's MFA policy.

The test covers the connected organization's current policy. It does not assess every organization in an enterprise or every authentication event. Invalid account-model values or a mismatch between the configured and connected organization produce **Error**. Cached evidence keeps its original collection timestamps; use a new `Invoke-Maester` run or reconnect to assess changed settings.

#### Permissions required

Use an organization owner with a classic PAT or OAuth token carrying `admin:org` to read the full organization settings. Support for other token types at the endpoint does not guarantee that GitHub returns the field this test needs. Maester's membership and Actions checks at connection time do not establish that visibility.

For GHE.com, use its dedicated API host and a token for that host. The test does not add scopes or introduce another authentication flow.

#### Remediation action

1. On the connected GitHub web host, open **Your organizations**, select the organization, then go to **Settings** > **Authentication security**.
2. Coordinate 2FA enrollment and recovery with organization owners and affected contributors. Review GitHub's [enforcement effects](https://docs.github.com/en/enterprise-cloud@latest/organizations/keeping-your-organization-secure/managing-two-factor-authentication-for-your-organization/requiring-two-factor-authentication-in-your-organization) before enabling the policy.
3. Select **Require two-factor authentication for everyone in your organization**, save, and complete any confirmation GitHub requires.
4. Run the test again. For managed users, review the identity provider's MFA policy through a supported process instead of changing the GitHub organization 2FA setting.

#### Related links

* [CIS GitHub Benchmark](https://www.cisecurity.org/benchmark/github)
* [GitHub organization API](https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/orgs?apiVersion=2026-03-10#get-an-organization)
* [Require organization two-factor authentication](https://docs.github.com/en/enterprise-cloud@latest/organizations/keeping-your-organization-secure/managing-two-factor-authentication-for-your-organization/requiring-two-factor-authentication-in-your-organization)
* [Managed-user abilities and restrictions](https://docs.github.com/en/enterprise-cloud@latest/admin/managing-iam/understanding-iam-for-enterprises/abilities-and-restrictions-of-managed-user-accounts)

<!--- Results --->
%TestResult%
