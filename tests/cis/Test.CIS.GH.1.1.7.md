1.1.7 (L1) Ensure code owner's review is required when a change affects owned code

CIS Benchmark: CIS GitHub Benchmark v1.2.0. Assessment Status: Manual.
Source: section 1.1.7, physical PDF pages 31–32; printed pages 30–31.

#### Rationale

Requiring designated owners to approve changes to owned code adds a review barrier against malicious software supply-chain changes.

#### Assessment and scope

This native check assesses explicitly identified main branches. Configure the authoritative repository inventory and applicable branch declarations in [GitHub CIS configuration](https://maester.dev/docs/next/configuration/github-cis). A successful connection or visible repository list does not establish complete scope.

Read-only evidence comes from `GET /repos/{owner}/{repo}/branches/{branch}/protection`, explicitly using REST version `2026-03-10`. The decisive evidence is `required_pull_request_reviews.require_code_owner_reviews`, expected to be **true**. Required values must have their documented types. Both status-check representations (`contexts` and `checks`) are validated where used; null application IDs are allowed by the schema.

The flag does not establish comprehensive CODEOWNERS coverage or the trust of its owners; those are separate CIS recommendations.

#### Permissions required

Repository discovery uses Metadata read. Classic protection and status-policy reads use repository Administration read; branch enumeration/diagnostics use Contents read. These operations support fine-grained PATs and GitHub App user/installation tokens at the API level. A classic user PAT with `repo` is the broad nonpublic path, constrained by the caller's actual access. Enterprise ownership alone does not prove repository access. Maester's current connection requires a user identity and active organization membership; this check does not add installation-token connection support.

#### Impact

Changes to owned areas need approval from designated owners. Coordinate with repository owners so ownership and review routing remain workable.

#### Remediation action

1. Identify every in-use repository and the branches covered by this recommendation. Reconcile public, internal, private, archived, and disabled repositories; do not exclude a repository just because it is archived.
2. On [GitHub](https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule), open the repository, then **Settings** > **Branches**. Use your deployment's host when working on GHE.com.
3. Edit the applicable classic branch protection rule, or add one covering the required branch. Select **Require a pull request before merging** and **Require review from Code Owners**.
4. Save the rule. Coordinate developer rollout and repeat the read-only assessment with the complete scope.

#### Result interpretation and limitations

Passed means the named CIS configuration audit is satisfied for the complete declared applicable population. A confirmed violation produces Failed even if other evidence is missing, with incomplete coverage disclosed. A required collection/execution error takes precedence and remains Error. Missing/null/unusable evidence and unresolved alternative enforcement produce an explicit indeterminate Skipped result. NotApplicable requires a complete, valid applicability inventory with justified exclusions; empty API output alone is insufficient.

Conforming classic evidence does not depend on additional ruleset bypass lists. Ruleset-only or potentially compensating alternatives remain indeterminate; the test does not calculate ruleset equivalence or certify enforcement against every actor. Separately returned bypass information is context, not an invented empty-list requirement.

Metadata collection distinguishes valid empty arrays from null/empty bodies and invalid collection items before aggregation. This is limited structural and decisive-field validation, not full raw-response schema validation. Evidence retains its original UTC collection interval; paginated reads are not atomic snapshots.

Standard GHEC, EMU, and GHE.com use repository-level evidence where available. GHE.com requires authenticated requests to its dedicated API host. Unsupported or unavailable evidence does not establish compliance. No tenant settings are changed by this assessment.

#### Related links

* [CIS GitHub Benchmark](https://www.cisecurity.org/benchmark/github)
* [GitHub protection REST operations](https://docs.github.com/en/enterprise-cloud@latest/rest/branches/branch-protection?apiVersion=2026-03-10)
* [GitHub protected branch behavior](https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
* [GitHub branch enumeration](https://docs.github.com/en/enterprise-cloud@latest/rest/branches/branches?apiVersion=2026-03-10#list-branches)
* [Applicable active rules](https://docs.github.com/en/enterprise-cloud@latest/rest/repos/rules?apiVersion=2026-03-10#get-rules-for-a-branch)

<!--- Results --->
%TestResult%
