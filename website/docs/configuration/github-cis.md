---
title: GitHub CIS configuration
description: Configure the organization, enterprise, repositories, and branches assessed by the GitHub CIS checks.
---

# GitHub CIS configuration

The GitHub CIS checks read the settings and access needed for their recommendations in CIS GitHub Benchmark v1.2.0. CIS lists these recommendations as Manual assessments. A pass means the settings checked by that test meet its requirements for the complete applicable scope. It does not replace the rest of the benchmark review or establish historical behavior.

Connect with `Connect-MtGitHub` before running the checks. A successful connection confirms a user identity and active organization membership. The account still needs access to the repositories, enterprise, and policy fields each check reads. Use credentials for the connected host on GitHub Enterprise Cloud, Enterprise Managed Users (EMU), or GHE.com. This connection does not support GitHub Enterprise Server or GitHub AE.

## Configure the assessment

Add these values to `GlobalSettings` in your [run configuration](./run-configuration.md):

| Setting | Default | Meaning |
| --- | --- | --- |
| `GitHubAccountModel` | `Unknown` | Use `PersonalAccounts` or `EnterpriseManagedUsers` for the organization's account model. The two organization MFA checks use this value. |
| `GitHubEnterprise` | empty string | The enterprise slug used to establish organization verification scope and to select the enterprise notification setting. |
| `GitHubCisRepositoryScope` | empty object | The organization repository inventory, whether each repository is in use, and the branch names each check needs. |

The example uses synthetic IDs and branch classifications. Replace them with the organization's reviewed inventory. A branch name alone does not establish that it is a main, production, or long-standing branch.

```json
{
  "GlobalSettings": {
    "GitHubOrganization": "example-organization",
    "GitHubAccountModel": "PersonalAccounts",
    "GitHubEnterprise": "example-enterprise",
    "GitHubCisRepositoryScope": {
      "Organization": "example-organization",
      "Complete": true,
      "Repositories": [
        {
          "Id": 101,
          "InUse": true,
          "MainBranches": ["main"],
          "LongStandingBranches": ["release/1"]
        },
        {
          "Id": 102,
          "InUse": false,
          "ExclusionReason": "Retired and no longer used; applicability reviewed by the repository owner."
        }
      ]
    }
  }
}
```

### Repositories and completeness

`Organization` must exactly match the connected organization. Each repository needs a positive numeric `Id` and Boolean `InUse`. Use REST database IDs, not names or GraphQL node IDs. These numeric IDs differ from the string IDs used by [GitHub deletion approvals](./github-deletion-policy.md).

Set `Complete` to `true` only after comparing the declaration with an authoritative organization inventory. It is your confirmation of scope; it does not establish that the token can see every repository. Maester reads every page of the organization's repository list and compares its IDs with the declaration.

Account for public, internal, private, archived, and disabled repositories. Every returned repository needs a classification, and every declared repository must be accounted for. A repository with `InUse: false` needs a nonempty `ExclusionReason`. Archived status alone does not justify exclusion. Missing repositories, unclassified repositories, or incomplete visibility prevent an overall pass.

To test one repository in an organization with several repositories, declare that repository's real ID and branch names and leave `Complete: false`. Maester can assess it and report a confirmed failure. Conforming findings remain incomplete at the organization level while other repositories are unclassified. Classify all repositories before expecting a complete organization pass; exclude a repository only when there is a reviewed reason it does not apply.

### Branch declarations

| Checks | Branches assessed |
| --- | --- |
| `CIS.GH.1.1.4`, `1.1.7`, `1.1.9`, `1.1.10`, `1.1.11`, `1.1.14`, `1.1.17` | The nonempty `MainBranches` list for each in-use repository. |
| `CIS.GH.1.1.12` | Every existing branch from every page of the branch list, without filtering for protection. `MainBranches` is not required. |
| `CIS.GH.1.1.16` | `MainBranches` and `LongStandingBranches`. Supply an empty long-standing array only when there are no additional maintained branches. |
| `CIS.GH.1.1.20` | The API's actual default branch and the declared main branches. |

Long-standing branches are branches your team maintains over time, such as an integration branch or a supported release line. List additional maintained branches beyond `MainBranches`, using their actual names. An old, abandoned feature branch does not qualify merely because of its age. REST requests use concrete branch names, not wildcard patterns.

Each check requires only the declarations and API reads it uses. For example, omitting `LongStandingBranches` does not block checks that assess only main branches, and a failed signature-policy read does not invalidate sufficient evidence for another setting.

Missing settings and incomplete declarations produce an indeterminate result. Supplied values with invalid types or contradictory organization identities produce **Error**. Configuration objects merge recursively, while arrays replace the earlier array, including when the new array is empty. Each run uses its resolved declaration; Maester does not cache classifications or verdicts.

## Organization MFA

`CIS.GH.1.3.4` and `CIS.GH.1.3.5` are separate CIS recommendations that check the same organization setting, `two_factor_requirement_enabled`. For `PersonalAccounts`, Boolean `true` passes and Boolean `false` fails. `Unknown` produces **Skipped**.

EMU, including GHE.com, uses the external identity provider for MFA. These GitHub-only checks remain **Skipped** for that account model, even when GitHub returns its organization 2FA setting. Provisioning, SSO, individual enrollment, and a successful connection do not establish the IdP's MFA policy. One organization's result does not assess every organization in an enterprise.

Use an organization owner with a classic PAT or OAuth token carrying `admin:org` to read full organization settings. Support for other token types at the endpoint does not guarantee access to every owner-only field.

## Organization verification and enterprise notifications

`CIS.GH.1.3.9` reads the connected organization's `isVerified` profile value through GraphQL. Before assessing it, Maester confirms that the same organization node ID appears in the enterprise selected by `GitHubEnterprise`. It reads later pages as needed and can stop at a valid match. A missing or inaccessible match produces **Skipped**; it does not establish that the organization has no enterprise relationship.

That check needs access to the organization and enterprise association fields. It does not request `ownerInfo` or assume that an enterprise-owner role or undocumented fine-grained permission is required. It does not count verified domains, require a verification DNS TXT record to remain, or assess every organization in the enterprise.

`CIS.GH.1.3.10` reads `Enterprise.ownerInfo.notificationDeliveryRestrictionEnabledSetting` for the enterprise selected by `GitHubEnterprise`. The result identifies that enterprise and API host. This enterprise-setting check does not require the connected organization to belong to the enterprise or attribute the policy to that organization.

Use an enterprise owner's classic PAT with `read:enterprise` or `admin:enterprise` for `ownerInfo`; prefer the read scope where sufficient. Scopes do not grant enterprise ownership, and the organization connection checks do not establish enterprise access.

`ENABLED` passes and `DISABLED` fails. Missing owner information, inaccessible fields, and unrecognized values produce **Skipped**. GitHub documents that an organization's restriction can become disabled when no eligible approved or verified domains remain. The enterprise setting does not prove that every organization or message is restricted.

## Branch protection and rulesets

The branch checks read the classic branch protection settings named by CIS. A conforming classic setting can pass without reading extra ruleset bypass lists. Administrator enforcement has its own check. The tests do not require every bypass list to be empty or claim that every actor is unable to bypass a policy.

When classic settings are nonconforming or ambiguous, Maester reads applicable active rules where needed to determine whether another policy may provide protection. Ruleset-only or possibly equivalent protection remains **Skipped** for review. The checks do not calculate ruleset equivalence. Unrelated rules do not establish compliance, and an additional ruleset does not weaken an already applicable conforming classic rule.

The status-check tests use GitHub's documented successful, skipped, and neutral conclusions. The signed-commit test reads the current requirement for every existing branch; it does not verify historical signatures or establish author trust. The default-branch test requires an applicable classic protection rule without choosing a minimum set of settings for it. Other recommendations check the individual settings.

## Understand the results

| Result | Meaning |
| --- | --- |
| `Passed` | Every required setting is satisfied across the complete applicable scope. |
| `Failed` | Returned evidence confirms a violation and no required execution error occurred. Any additional coverage gaps remain visible. |
| `Skipped` | Required evidence is missing, null, invalid, or unavailable, or alternative protection remains unresolved, with no confirmed violation. The report explains what could not be checked. |
| `Error` | Invalid configuration or a required request, JSON parsing, or collection failure stops the assessment. Earlier findings remain available but do not establish a complete result. |
| `NotApplicable` | A complete, valid declaration with justified exclusions leaves no applicable repositories. |

A 404 from a protection or signature endpoint alone does not prove that protection is disabled. GitHub can also hide inaccessible private resources with 404. Maester checks the context before deciding the result. Other request failures are not treated as unprotected branches. An unexplained empty collection cannot establish **Passed** or **NotApplicable**.

## Collection and caching

New REST reads use version `2026-03-10`. `GitHubApiVersion` keeps its `2022-11-28` default for existing callers. GraphQL uses the connected `/graphql` endpoint and its own schema; the REST version header does not version it. API support for installation tokens does not add installation-token support to Maester's user connection.

REST reads that include metadata use separate cache entries from body-only reads, and full pagination is separate from a single-page read. Collection checks distinguish JSON `[]` from null, blank content, and invalid items. Maester checks the structure and fields required by each assessment, rather than the whole response schema. Failed or incomplete collections are not cached as complete evidence.

Evidence remains in the session cache without a fixed expiry. A cache hit keeps the original UTC collection interval. Each `Invoke-Maester` run clears the shared GitHub cache before collecting evidence. Reconnect, disconnect, and module reset also clear it. Standalone `Invoke-MtTest` calls reuse that cache; waiting does not refresh it. Start a new run or reconnect to assess changed settings. Checks use the cache throughout a run.

GraphQL cache entries are identified by the endpoint, query, and variables. Maester recomputes the assessment from the current configuration when it reuses evidence. Collection timestamps do not mean all settings were read at the same instant, and paginated responses can span concurrent changes.

### Rate limits

An explicit rate limit pauses affected outbound requests for the authenticated connection and API host, including later pages and checks. REST and GraphQL primary quotas are separate; a secondary limit pauses both APIs. Maester honors `Retry-After` and primary reset times, keeps completed findings, and reports incomplete collection as **Error**.

There is no automatic retry or sleep. Cached evidence remains available, but disabling the cache does not bypass the pause. Clearing the cache for a new run also preserves the pause. If a primary response has no usable reset time, the connection stays paused until it is replaced. Reconnect only when GitHub permits requests again.

## Reports and private configuration

`GitHubEnterprise` and the whole `GitHubCisRepositoryScope` value are sensitive settings. Exported configuration, including JSON and the data embedded in HTML, shows them as `<redacted>`. The input file and live settings remain usable by the checks. This does not anonymize identifiers or scope explanations included in the assessment findings.

Keep actual configuration, reports, tokens, and benchmark source files out of contributions. Synthetic fixtures establish the code paths they exercise; they do not establish authenticated behavior for every GHEC, EMU, or GHE.com environment. These checks read configuration and do not change tenant settings.

## Related links

- [Organization REST fields](https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/orgs?apiVersion=2026-03-10#get-an-organization)
- [Repository inventory](https://docs.github.com/en/enterprise-cloud@latest/rest/repos/repos?apiVersion=2026-03-10#list-organization-repositories)
- [Branch enumeration](https://docs.github.com/en/enterprise-cloud@latest/rest/branches/branches?apiVersion=2026-03-10#list-branches)
- [Protection and policy reads](https://docs.github.com/en/enterprise-cloud@latest/rest/branches/branch-protection?apiVersion=2026-03-10)
- [Applicable active rules](https://docs.github.com/en/enterprise-cloud@latest/rest/repos/rules?apiVersion=2026-03-10#get-rules-for-a-branch)
- [Ruleset layering](https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [Organization verification](https://docs.github.com/en/enterprise-cloud@latest/graphql/reference/orgs#organization)
- [Enterprise fields and owner access](https://docs.github.com/en/enterprise-cloud@latest/graphql/reference/enterprise-admin#enterprise)
- [Enterprise notification restrictions](https://docs.github.com/en/enterprise-cloud@latest/admin/enforcing-policies/enforcing-policies-for-your-enterprise/restricting-email-notifications-for-your-enterprise)
- [GHE.com feature and API differences](https://docs.github.com/en/enterprise-cloud@latest/admin/data-residency/feature-overview-for-github-enterprise-cloud-with-data-residency)
- [GitHub rate-limit handling](https://docs.github.com/en/enterprise-cloud@latest/rest/using-the-rest-api/best-practices-for-using-the-rest-api#handle-rate-limit-errors-appropriately)
