The default branch and declared main branches have branch protection.

Protecting these branches helps prevent unauthorized changes from entering the software supply chain. The effect on developers depends on the policies repository owners choose for each rule.

CIS GitHub Benchmark v1.2.0 lists section 1.1.20 as a Manual assessment. This test checks the actual default branch and the declared main branches using `GET /repos/{owner}/{repo}/branches/{branch}/protection` with REST version `2026-03-10`. The benchmark source is section 1.1.20, physical PDF pages 57–58; printed pages 56–57.

The test passes for a branch when GitHub returns a classic protection object whose URL identifies that repository and branch on the connected API host. An accessible existing branch confirmed to be unprotected fails. Missing or unusable evidence, including protection that may come only from rulesets, produces **Skipped**.

CIS does not prescribe a minimum set of protection settings for this recommendation. The other branch checks assess those settings separately. A branch's protected flag alone is insufficient because GitHub also uses it for ruleset protection.

Configure the repositories and branch names in [GitHub CIS configuration](https://maester.dev/docs/next/configuration/github-cis). A pass requires complete coverage of the declared applicable repositories and branches. A confirmed violation can fail the check while other coverage remains incomplete; the report keeps those gaps visible. A complete declaration with justified exclusions and no applicable repositories produces **NotApplicable**. An empty API response alone does not establish that result.

A 404 response alone does not prove a branch is unprotected, because GitHub can hide inaccessible resources with that status. Where needed, Maester reads the branch and applicable active rules before deciding the result. Ruleset-only or possibly equivalent protection remains **Skipped** for review. A conforming classic setting can pass without requiring empty bypass lists. Required request, JSON parsing, or collection failures produce **Error**, even when earlier findings are available.

The test reads the current configuration and keeps its original UTC collection interval. Paginated reads can span concurrent changes. It checks the fields needed for this assessment, rather than the entire response schema, historical merges, or enforcement against every actor. It does not change repository settings.

#### Permissions required

Use a classic PAT with `repo` and an account with access to the repositories being assessed. Token scopes and enterprise ownership do not grant repository access. With fine-grained tokens, repository discovery uses **Metadata: read**, classic protection reads use **Administration: read**, and branch listing or diagnostics use **Contents: read**.

The API operations support fine-grained PATs and GitHub App user or installation tokens. Maester's connection requires a user identity and active organization membership, so it does not support installation tokens. For GHE.com, use its dedicated API host and a token for that host. The same missing-data rules apply to GHEC, Enterprise Managed Users, and GHE.com.

#### Remediation action

1. Review the in-use repository inventory and required branch declarations. Account for public, internal, private, archived, and disabled repositories; archived status alone is not a reason to exclude one.
2. On the connected GitHub web host (`github.com` or your enterprise's `SUBDOMAIN.ghe.com`), open the repository, then **Settings** > **Branches**.
3. Add or edit a classic branch protection rule that covers the default branch and each separately declared main branch. Configure the policies the repository owners require.
4. Save the rule, coordinate the change with affected contributors, and run the test again with the reviewed scope.

#### Related links

* [CIS GitHub Benchmark](https://www.cisecurity.org/benchmark/github)
* [GitHub: Managing a branch protection rule](https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule)
* [GitHub protection REST operations](https://docs.github.com/en/enterprise-cloud@latest/rest/branches/branch-protection?apiVersion=2026-03-10)
* [GitHub protected branch behavior](https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
* [GitHub branch enumeration](https://docs.github.com/en/enterprise-cloud@latest/rest/branches/branches?apiVersion=2026-03-10#list-branches)
* [Applicable active rules](https://docs.github.com/en/enterprise-cloud@latest/rest/repos/rules?apiVersion=2026-03-10#get-rules-for-a-branch)

<!--- Results --->
%TestResult%
