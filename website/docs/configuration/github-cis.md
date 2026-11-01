---
title: GitHub CIS configuration
description: Explicit assessment targets, repository applicability, and evidence requirements for the GitHub CIS checks.
---

# GitHub CIS configuration

The GitHub CIS checks collect read-only evidence for the GitHub configuration audits in CIS GitHub Benchmark
v1.2.0. CIS marks these recommendations as Manual. A Passed result means the implemented configuration audit
is satisfied for its stated target and complete applicable population; it does not certify the whole benchmark,
historical behavior, or every possible enforcement path.

Connect with `Connect-MtGitHub` before running the checks. Connection success establishes a user identity and
active organization membership. It does not prove complete repository visibility, enterprise ownership, or access
to every policy field. Use host-appropriate credentials on standard GitHub Enterprise Cloud, EMU, or GHE.com;
GitHub Enterprise Server and GitHub AE are not supported by this connection.

## Assessment settings

Set the following in `GlobalSettings` in the [run configuration](./run-configuration.md). Defaults deliberately
leave the new assessment context unconfirmed.

| Setting | Default | Meaning |
| --- | --- | --- |
| `GitHubAccountModel` | `Unknown` | `Unknown`, `PersonalAccounts`, or `EnterpriseManagedUsers`. Used by the two organization MFA checks. |
| `GitHubEnterprise` | empty string | Explicit enterprise slug used for organization verification applicability and the independently targeted enterprise notification check. |
| `GitHubCisRepositoryScope` | empty object | Authoritative organization repository applicability inventory and the branch classifications needed by the selected branch checks. |

The following is an illustrative configuration, not a discovered or recommended inventory. Replace every
repository ID and classification with the organization's actual authoritative scope. Do not infer production/main
or long-standing status from a convenient branch name.

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

`Complete` must be a Boolean. It is an assessor's applicability declaration, not evidence that an API token can
see everything. Reconcile it with an authoritative repository inventory. Maester reads every page of the connected
organization's repository listing and compares repository IDs with the declaration. Public, internal, private,
archived, and disabled repositories remain accounted for. Archived status alone does not justify exclusion.

Each repository needs a numeric `Id` and Boolean `InUse`. Excluded repositories need a nonempty
`ExclusionReason`. Every declared repository must be accounted for and every returned repository must be
classified. A mismatch or incomplete visibility prevents a complete aggregate pass. New API evidence must identify
the repository; names are not substituted for stable repository IDs.

### Control-specific branch declarations

| Checks | Additional required population |
| --- | --- |
| `CIS.GH.1.1.4`, `1.1.7`, `1.1.9`, `1.1.10`, `1.1.11`, `1.1.14`, `1.1.17` | Explicit nonempty `MainBranches` for each in-use repository. |
| `CIS.GH.1.1.12` | Every existing branch from every branch-list page, without a protected filter. No main-branch classification is required. |
| `CIS.GH.1.1.16` | `MainBranches` and explicit `LongStandingBranches`; use an empty array only when the authoritative classification contains no additional trunk/long-standing branches. |
| `CIS.GH.1.1.20` | The API's actual default branch plus explicitly identified main branches. |

Shared collectors reuse reads without making every check require every endpoint or scope field. For example,
signature-policy failure does not invalidate independently sufficient classic-policy evidence, and an omitted
long-standing declaration does not block checks that do not use it.

Missing/default context and incomplete declarations are indeterminate. Provided malformed types and contradictory
target identities are configuration errors. Only fields relevant to the selected assessment are prerequisites.
Configuration layers follow the normal resolver: objects merge recursively and arrays replace, including an empty
array clearing a lower layer. Each invocation uses its resolved scope; previous verdicts or classifications are not
cached.

## Organization MFA

`CIS.GH.1.3.4` and `CIS.GH.1.3.5` remain distinct recommendations even though they read the same Boolean
`two_factor_requirement_enabled` from the connected organization. Personal-account organizations can be assessed
from that policy. `Unknown` remains indeterminate. EMU, including GHE.com, depends on external identity-provider
MFA evidence and remains indeterminate in these GitHub-only checks.

Provisioning, SSO presence, individual enrollment, or a successful connection does not prove that policy. A result
for one organization does not assess every organization in an enterprise. Full organization settings are documented
for an organization owner with a classic PAT/OAuth token carrying `admin:org`; general endpoint support for other
token types does not guarantee that every owner-only field is returned.

## Organization verification and enterprise notifications

`CIS.GH.1.3.9` assesses the connected organization's verified profile state through GraphQL `Organization.isVerified`.
It first requires positive association with the explicitly selected enterprise, using the organization node ID in
that enterprise's organization connection. The lookup may stop when it finds a valid positive match. A missing
match is indeterminate, not proof that no enterprise relationship exists. It does not request or require
`ownerInfo`, persist a DNS TXT requirement, count verified domains, or claim enterprise-wide organization coverage.
Use supported authentication with access to the returned organization and association fields; do not assume
undocumented field-specific fine-grained permissions.

`CIS.GH.1.3.10` independently targets the enterprise named by `GitHubEnterprise`. Its evidence identifies that
enterprise and API host, without attributing its policy to the connected organization. The scalar
`Enterprise.ownerInfo.notificationDeliveryRestrictionEnabledSetting` requires enterprise-owner visibility. GitHub
documents enterprise owners' classic PATs with `read:enterprise` or `admin:enterprise`; prefer the read scope where
sufficient. Organization connection probes do not establish enterprise access. No organization-association query
is needed for this independent target.

`ENABLED` satisfies the named enterprise-setting audit and `DISABLED` fails it. Missing owner information,
inaccessible fields, or unknown values are indeterminate. GitHub documents an organization exception when no
eligible approved or verified domains remain. A Passed enterprise scalar does not establish actual delivery
behavior for every organization or message.

## Branch configuration and alternative enforcement

The branch checks assess the named classic protection settings in the benchmark. Valid conforming classic
evidence does not depend on reading additional rulesets' bypass lists. Administrator enforcement is assessed by
its own checkbox recommendation; no check invents a requirement that every bypass list be empty or every actor
be unable to bypass every policy.

For negative or ambiguous classic evidence, applicable active rules are read where needed to avoid mistaking
alternative protection for absence. Ruleset-only or potentially compensating enforcement remains indeterminate;
there is no ruleset-equivalence scoring engine. Unrelated rules supply no compliance credit. Additional rulesets
cannot weaken an already applicable conforming classic rule. Branch names are concrete, not wildcard patterns
sent to REST endpoints.

Required status checks use GitHub's documented status semantics, including acceptable successful, skipped, or
neutral conclusions. Required-signature checks assess the current native policy across every existing branch,
not historical signatures or author trust. Main/default protection does not invent a minimum bundle of settings;
other recommendations assess the individual policies.

## Results, evidence intervals, and caching

| Evidence | Result |
| --- | --- |
| Complete applicable population and every required predicate satisfied | Passed |
| Confirmed violation, with no required execution error | Failed; additional missing evidence remains disclosed as incomplete coverage |
| Missing/null/unusable required evidence or unresolved alternative enforcement, without a confirmed violation | Custom Skipped with an explicit indeterminate reason |
| Required request, parsing, or collection execution error, including alongside a confirmed violation | Error; retained findings do not imply complete coverage |
| Complete valid applicability evidence with justified exclusions leaving no applicable objects | NotApplicable |

A 404 from a protection/signature endpoint may be expected for unavailable protection and is contextualized. It
is not proof that the setting is disabled: GitHub also masks inaccessible private resources with 404. Other
request failures are not silently converted into unprotected branches. An unexplained empty population cannot
become Passed or NotApplicable.

New collectors explicitly request REST `2026-03-10`; `GitHubApiVersion` retains its existing `2022-11-28` default
for legacy callers. GraphQL uses its own schema and the configured `/graphql` host; the REST version header does
not version it. Pure installation-token connection support is not added merely because an API operation accepts
installation tokens.

Metadata-bearing REST reads are isolated from body-only legacy cache entries and separate single-page reads from
full pagination. Collection checks distinguish JSON `[]` from JSON null, blank content, and invalid items before
aggregation. This is limited structural and decisive-field checking, not complete raw-response schema validation.
Failed/incomplete collections are not cached as complete evidence.

Cached evidence does not expire after a fixed time. A cache hit keeps the original UTC collection timestamps;
it does not mean GitHub was queried again. Each `Invoke-Maester` run clears the shared GitHub cache before
collecting evidence. Reconnect, disconnect, and module reset also clear it.

Standalone `Invoke-MtTest` calls reuse the session cache. Waiting does not refresh that evidence. To check
changed GitHub settings, start a new `Invoke-Maester` run or reconnect. Checks use the cache throughout a run.

GraphQL cache entries are identified by the endpoint, query, and variables. Maester recomputes applicability
and results from the current assessment configuration when it reuses evidence. The collection timestamps
do not mean that all GitHub settings were read at the same instant.

Keep actual assessment configuration, reports, tokens, and benchmark source inputs out of contributions. Synthetic
fixtures establish the exercised code behavior, not authenticated GHEC/EMU/GHE.com behavior. These checks do not
write tenant settings or perform remediation.

Explicit rate limiting pauses affected outbound requests for the authenticated connection and API host, including
later pages and checks. Primary REST and GraphQL quotas stay separate; secondary limits stop both APIs. Maester
honors `Retry-After` and primary reset times, retains completed findings, and reports incomplete collection as Error.
There is no automatic retry or sleep. Cache reads remain available, but disabling the cache does not bypass the
pause. Per-run cache clearing preserves the pause. If a primary response has no usable reset time, the connection
remains blocked until it is replaced; reconnect only when GitHub permits requests again.

`GitHubEnterprise` and the entire `GitHubCisRepositoryScope` value are registered as sensitive and appear as
`<redacted>` in exported result configuration, including JSON and embedded HTML data. The input configuration and
live settings remain usable. This redaction does not anonymize identifiers or applicability explanations that a
check legitimately includes in assessment evidence.

## Official references

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
