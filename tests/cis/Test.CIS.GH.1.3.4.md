1.3.4 (L2) Ensure Multi-Factor Authentication (MFA) is required for contributors of new code

CIS Benchmark: CIS GitHub Benchmark v1.2.0. Assessment Status: Manual.
Source: section 1.3.4, physical PDF pages 82–83; printed pages 81–82.

#### Rationale

Organization two-factor enforcement reduces the risk that stolen passwords allow attackers to use outside collaborators' cloud accounts to change code.

#### Assessment and scope

This check delegates to [CIS.GH.1.3.5](https://maester.dev/docs/tests/CIS.GH.1.3.5), because both CIS audits assess the same organization two-factor setting. It reads `two_factor_requirement_enabled` from `GET /orgs/{org}`, explicitly using REST version `2026-03-10`. Boolean true passes and false fails. Missing, null, or wrongly typed evidence produces an explicit indeterminate Skipped result; request and JSON parsing failures remain Error. It concerns the connected organization, not every organization in an enterprise.

Set `GitHubAccountModel` to `PersonalAccounts` for this GitHub organization-policy audit. `Unknown` is indeterminate. EMU and GHE.com require external identity-provider MFA evidence and remain indeterminate here, including when a GitHub policy field is returned. Identity provisioning, SSO presence, individual 2FA enrollment, and the connection's success are not substitutes for the required policy.

#### Permissions required

GitHub documents organization-owner access with a classic PAT/OAuth token carrying `admin:org` for full organization details. General fine-grained/App endpoint support does not guarantee owner-only policy fields. Maester's active-membership and Actions probes do not establish that this field is visible. Use host-appropriate supported credentials; the check does not expand authentication scopes or consent.

#### Impact

Enforcement can remove or block access for members and outside collaborators who have not enrolled. Coordinate enrollment and recovery before enabling the policy; a staged rollout may be needed for many users.

#### Remediation action

1. Open [your organizations](https://github.com/settings/organizations), choose the organization, and open **Settings** > **Authentication security**. Use your deployment's host as appropriate.
2. Coordinate 2FA enrollment and review GitHub's [enforcement effects](https://docs.github.com/en/enterprise-cloud@latest/organizations/keeping-your-organization-secure/managing-two-factor-authentication-for-your-organization/requiring-two-factor-authentication-in-your-organization) with organization owners and affected contributors.
3. Select **Require two-factor authentication for everyone in your organization**, save, and complete any confirmation GitHub requires.
4. Repeat the read-only assessment. For managed users, assess the identity provider's MFA policy through a separately supported process instead of changing a GitHub organization 2FA setting.

#### Known limitations

This assesses the current organization configuration, not every authentication event or an enterprise-wide identity policy. Malformed account-model settings or a configured/connected organization mismatch are configuration errors. New metadata caches retain the actual evidence timestamps; synthetic validation does not prove authenticated platform behavior.

#### Related links

* [CIS GitHub Benchmark](https://www.cisecurity.org/benchmark/github)
* [GitHub organization API](https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/orgs?apiVersion=2026-03-10#get-an-organization)
* [Require organization two-factor authentication](https://docs.github.com/en/enterprise-cloud@latest/organizations/keeping-your-organization-secure/managing-two-factor-authentication-for-your-organization/requiring-two-factor-authentication-in-your-organization)
* [Managed-user abilities and restrictions](https://docs.github.com/en/enterprise-cloud@latest/admin/managing-iam/understanding-iam-for-enterprises/abilities-and-restrictions-of-managed-user-accounts)

<!--- Results --->
%TestResult%
