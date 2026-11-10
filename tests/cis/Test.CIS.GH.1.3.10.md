Enterprise email notifications are restricted to approved or verified domains.

Restricting notification destinations reduces exposure of source-code information in personal mailboxes that an attacker could compromise. Affected members may need to verify an address in an eligible domain to keep receiving notifications. Coordinate domain setup and communicate that change before enabling the restriction.

CIS GitHub Benchmark v1.2.0 lists section 1.3.10 as a Manual assessment (physical PDF pages 94–95; printed pages 93–94). This test reads `Enterprise.ownerInfo.notificationDeliveryRestrictionEnabledSetting` through `POST /graphql` for the enterprise named by `GitHubEnterprise`.

The test passes when the setting is `ENABLED` and fails when it is `DISABLED`. Missing enterprise context, unavailable owner information, denied fields, and unrecognized values produce **Skipped**, with a reason explaining what could not be checked. Invalid configuration, request failures, JSON parsing failures, and unexpected execution failures produce **Error**.

The result identifies the selected enterprise and API host. This is an enterprise-setting check; it does not require the connected organization to belong to that enterprise or attribute the policy to that organization. Organization notification settings and verified-domain counts do not decide the result.

The setting does not prove that every organization or message is restricted. GitHub documents that an organization's restriction can become disabled when no approved or verified domains remain, including inherited domains. Domain approval is a preview feature where GitHub documents it; unavailable features or fields produce no assumed pass.

GraphQL uses the connected API host, including the dedicated GHE.com host. Its schema is not versioned by the REST version header. The test does not change notification or domain settings.

#### Permissions required

Use an enterprise owner with a classic PAT carrying `read:enterprise` or `admin:enterprise` to read `ownerInfo`; prefer `read:enterprise` where sufficient. Token scopes do not grant the enterprise-owner role. Organization REST permissions and a successful Maester connection do not establish enterprise access. This check does not assume undocumented fine-grained or App permissions, add scopes, or introduce another authentication flow.

#### Remediation action

1. An enterprise owner should open the intended enterprise's **Settings** > **Verified & approved domains**.
2. Verify or approve the eligible domains and coordinate with organization owners. Members need verified email addresses in eligible domains to continue receiving notifications.
3. Under **Notification preferences**, select **Restrict email notifications to only approved or verified domains** and save.
4. Run the test again and review each organization's eligible-domain coverage separately.

#### Related links

* [CIS GitHub Benchmark](https://www.cisecurity.org/benchmark/github)
* [Enterprise owner information](https://docs.github.com/en/enterprise-cloud@latest/graphql/reference/enterprise-admin#enterpriseownerinfo)
* [Notification restriction enum](https://docs.github.com/en/enterprise-cloud@latest/graphql/reference/activity#notificationrestrictionsettingvalue)
* [Enterprise email notification restrictions](https://docs.github.com/en/enterprise-cloud@latest/admin/enforcing-policies/enforcing-policies-for-your-enterprise/restricting-email-notifications-for-your-enterprise)

<!--- Results --->
%TestResult%
