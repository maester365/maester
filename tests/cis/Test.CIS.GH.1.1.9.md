Branches require configured status checks before changes can be merged.

Required checks help prevent unsafe or malicious changes from entering the software supply chain. Developers must address failing checks before merging; repository owners need to agree on the required job names and keep those jobs reliable.

CIS GitHub Benchmark v1.2.0 lists section 1.1.9 as a Manual assessment. This test checks the declared main branches using `GET /repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks` with REST version `2026-03-10`. The benchmark source is section 1.1.9, physical PDF pages 35–36; printed pages 34–35.

The test requires valid `contexts` and `checks` arrays with at least one required check between them. Context names must be nonempty strings; check entries need a nonempty context and a numeric or null application ID. A valid empty required-check set fails when alternative protection has been ruled out. Missing or invalid values produce **Skipped**.

The CIS audit names the status-check checkbox, while its description and rationale also require predefined checks. The test uses those requirements together. CIS does not name the jobs or specify a numeric minimum. The API-to-checkbox mapping for an empty set has not been confirmed against a live platform.

GitHub accepts successful, skipped, or neutral conclusions for required checks. This test reads the configured requirements; it does not inspect historical check runs or choose required jobs for the organization.

Configure the repositories and branch names in [GitHub CIS configuration](https://maester.dev/docs/next/configuration/github-cis). A pass requires complete coverage of the declared applicable repositories and branches. A confirmed violation can fail the check while other coverage remains incomplete; the report keeps those gaps visible. A complete declaration with justified exclusions and no applicable repositories produces **NotApplicable**. An empty API response alone does not establish that result.

A 404 response alone does not prove a branch is unprotected, because GitHub can hide inaccessible resources with that status. For a protected branch, Maester also reads classic protection. A matching protection URL with the `required_status_checks` field omitted corroborates that the status-check policy is absent; it fails only after applicable active rules rule out alternative protection. A null, malformed or contradictory field remains **Skipped**. This combines the documented response schema with the 404 response; the disabled-policy response has not been verified against a live tenant. Ruleset-only or possibly equivalent protection remains **Skipped** for review. A conforming classic setting can pass without requiring empty bypass lists. Required request, JSON parsing, or collection failures produce **Error**, even when earlier findings are available.

The test reads the current configuration and keeps its original UTC collection interval. Paginated reads can span concurrent changes. It checks the fields needed for this assessment, rather than the entire response schema, historical merges, or enforcement against every actor. It does not change repository settings.

#### Permissions required

Use a classic PAT with `repo` and an account with access to the repositories being assessed. Token scopes and enterprise ownership do not grant repository access. With fine-grained tokens, repository discovery uses **Metadata: read**, classic protection reads use **Administration: read**, and branch listing or diagnostics use **Contents: read**.

The API operations support fine-grained PATs and GitHub App user or installation tokens. Maester's connection requires a user identity and active organization membership, so it does not support installation tokens. For GHE.com, use its dedicated API host and a token for that host. The same missing-data rules apply to GHEC, Enterprise Managed Users, and GHE.com.

#### Remediation action

1. Review the in-use repository inventory and required branch declarations. Account for public, internal, private, archived, and disabled repositories; archived status alone is not a reason to exclude one.
2. On the connected GitHub web host (`github.com` or your enterprise's `SUBDOMAIN.ghe.com`), open the repository, then **Settings** > **Branches**.
3. Edit the applicable classic branch protection rule, or add one covering the required branches. Select **Require status checks to pass before merging** and configure the checks the repository owners require.
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
