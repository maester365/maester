Every existing branch requires signed commits.

Requiring signed commits helps prevent an attacker from introducing unsigned changes into the software supply chain. Contributors may need to set up signing and configure Git to sign commits automatically. Their usual commit commands can then stay the same. Plan a pilot and communicate the change, because contributors and bots need verified signatures and existing unsigned pull-request commits may need to be rewritten and signed before merging.

CIS GitHub Benchmark v1.2.0 lists section 1.1.12 as a Manual assessment. This test checks every existing branch in each in-use repository using `GET /repos/{owner}/{repo}/branches/{branch}/protection/required_signatures` with REST version `2026-03-10`. The benchmark source is section 1.1.12, physical PDF pages 41–42; printed pages 40–41.

The test passes for a branch when `enabled` is Boolean `true`. Boolean `false` fails when alternative protection has been ruled out. A missing, null, or non-Boolean value produces **Skipped**, with a reason explaining what could not be checked.

This checks the current signature requirement. It does not verify historical commits, establish that an author is trusted, or require a particular signing key. GitHub's documented merge and vigilant-mode behavior still applies.

Configure the repositories and branch names in [GitHub CIS configuration](https://maester.dev/docs/next/configuration/github-cis). A pass requires complete coverage of the declared applicable repositories and branches. A confirmed violation can fail the check while other coverage remains incomplete; the report keeps those gaps visible. A complete declaration with justified exclusions and no applicable repositories produces **NotApplicable**. An empty API response alone does not establish that result. The test reads every page of existing branches without filtering for protection; it does not require `MainBranches`.

A 404 response alone does not prove a branch is unprotected, because GitHub can hide inaccessible resources with that status. Where needed, Maester reads the branch and applicable active rules before deciding the result. Ruleset-only or possibly equivalent protection remains **Skipped** for review. A conforming classic setting can pass without requiring empty bypass lists. Required request, JSON parsing, or collection failures produce **Error**, even when earlier findings are available.

The test reads the current configuration and keeps its original UTC collection interval. Paginated reads can span concurrent changes. It checks the fields needed for this assessment, rather than the entire response schema, historical merges, or enforcement against every actor. It does not change repository settings.

#### Permissions required

Use a classic PAT with `repo` and an account with access to the repositories being assessed. Token scopes and enterprise ownership do not grant repository access. With fine-grained tokens, repository discovery uses **Metadata: read**, classic protection reads use **Administration: read**, and branch listing or diagnostics use **Contents: read**. GitHub also requires repository administrator or owner access to read the signature policy.

The API operations support fine-grained PATs and GitHub App user or installation tokens. Maester's connection requires a user identity and active organization membership, so it does not support installation tokens. For GHE.com, use its dedicated API host and a token for that host. The same missing-data rules apply to GHEC, Enterprise Managed Users, and GHE.com.

#### Remediation action

1. Review the in-use repository inventory and required branch declarations. Account for public, internal, private, archived, and disabled repositories; archived status alone is not a reason to exclude one.
2. On the connected GitHub web host (`github.com` or your enterprise's `SUBDOMAIN.ghe.com`), open the repository, then **Settings** > **Branches**.
3. Edit the applicable classic branch protection rule, or add one covering the required branches. Select **Require signed commits** in rules covering every existing branch.
4. Save the rule, coordinate the change with affected contributors, and run the test again with the reviewed scope.

#### Related links

* [CIS GitHub Benchmark](https://www.cisecurity.org/benchmark/github)
* [GitHub: Managing a branch protection rule](https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule)
* [GitHub protection REST operations](https://docs.github.com/en/enterprise-cloud@latest/rest/branches/branch-protection?apiVersion=2026-03-10)
* [GitHub: Signing commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits)
* [GitHub protected branch behavior](https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
* [GitHub branch enumeration](https://docs.github.com/en/enterprise-cloud@latest/rest/branches/branches?apiVersion=2026-03-10#list-branches)
* [Applicable active rules](https://docs.github.com/en/enterprise-cloud@latest/rest/repos/rules?apiVersion=2026-03-10#get-rules-for-a-branch)

<!--- Results --->
%TestResult%
