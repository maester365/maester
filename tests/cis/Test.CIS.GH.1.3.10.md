1.3.10 (L2) Ensure Source Code Management (SCM) email notifications are restricted to verified domains

CIS Benchmark: CIS GitHub Benchmark v1.2.0. Assessment Status: Manual.
Source: section 1.3.10, physical PDF pages 94–95; printed pages 93–94.

#### Rationale

Restricting notification destinations reduces exposure of source-code notifications in personal mailboxes that an attacker could collect remotely.

#### Assessment and scope

This independently targeted enterprise assessment reads `Enterprise.ownerInfo.notificationDeliveryRestrictionEnabledSetting` through `POST /graphql`. Set `GitHubEnterprise` explicitly. The result identifies the returned enterprise and API host; it does not attribute that policy to the connected organization or require proof that the organization belongs to this enterprise.

The documented enum `ENABLED` passes the exact enterprise-setting audit and `DISABLED` fails it. Missing enterprise context, null/withheld owner information, denied fields, and unknown values are indeterminate. Request/parsing and unexpected execution failures remain Error. Organization notification settings and verified-domain counts are not substituted for this field.

#### Permissions required

The field requires enterprise-owner information. GitHub documents enterprise owners or their classic PATs with `read:enterprise` or `admin:enterprise` for `ownerInfo`. Prefer the read scope when sufficient. Field-specific fine-grained/App permissions are not documented by this contract; organization REST permissions and a successful Maester connection do not establish enterprise access. No additional consent or authentication flow is introduced.

#### Impact

Members may stop receiving notifications until they verify an address in an eligible domain. Coordinate the domains, communication, and rollout with organization owners and users; test the effect before enforcing it broadly.

#### Remediation action

1. An enterprise owner should open the intended enterprise's **Settings** > **Verified & approved domains**; see [GitHub's enterprise notification guidance](https://docs.github.com/en/enterprise-cloud@latest/admin/enforcing-policies/enforcing-policies-for-your-enterprise/restricting-email-notifications-for-your-enterprise).
2. Verify or approve the eligible domains and coordinate with organization owners. Members must have verified email addresses in eligible domains to continue receiving notifications.
3. Under **Notification preferences**, select **Restrict email notifications to only approved or verified domains** and save.
4. Repeat the read-only assessment and review organizations' eligible-domain coverage separately.

#### Known limitations

This checks the named enterprise configuration, not actual delivery of every message. GitHub documents that an organization's restriction can become disabled when no approved or verified domains remain, including inherited domains. The scalar does not prove that every organization currently restricts delivery. Domain approval is a preview capability where GitHub documents it; unsupported feature/schema access is not an assumed pass.

GraphQL uses the configured authenticated API host, including the dedicated GHE.com host. Its schema is not pinned by the REST version header. The check never changes notification or domain settings.

#### Related links

* [CIS GitHub Benchmark](https://www.cisecurity.org/benchmark/github)
* [Enterprise owner information](https://docs.github.com/en/enterprise-cloud@latest/graphql/reference/enterprise-admin#enterpriseownerinfo)
* [Notification restriction enum](https://docs.github.com/en/enterprise-cloud@latest/graphql/reference/activity#notificationrestrictionsettingvalue)
* [Enterprise email notification restrictions](https://docs.github.com/en/enterprise-cloud@latest/admin/enforcing-policies/enforcing-policies-for-your-enterprise/restricting-email-notifications-for-your-enterprise)

<!--- Results --->
%TestResult%
