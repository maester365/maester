1.1.20 (L1) Ensure branch protection is enforced on the default branch

CIS Benchmark: CIS GitHub Benchmark v1.2.0. Assessment Status: Manual.
Source: section 1.1.20, physical PDF pages 57–58; printed pages 56–57.

#### Rationale

Protecting the default and main branches provides a policy boundary against unauthorized software supply-chain changes.

#### Assessment and scope

This native check assesses the actual default branch and explicitly identified main branches. Configure the authoritative repository inventory and applicable branch declarations in [GitHub CIS configuration](https://maester.dev/docs/next/configuration/github-cis). A successful connection or visible repository list does not establish complete scope.

Read-only evidence comes from `GET /repos/{owner}/{repo}/branches/{branch}/protection`, explicitly using REST version `2026-03-10`. The decisive evidence is `applicable classic protection object`, expected to be **present**. Required values must have their documented types. Both status-check representations (`contexts` and `checks`) are validated where used; null application IDs are allowed by the schema.

The benchmark does not prescribe a minimum bundle of branch settings here. A protected flag alone does not identify a classic protection rule because GitHub also reports ruleset protection.

#### Permissions required

Repository discovery uses Metadata read. Classic protection and status-policy reads use repository Administration read; branch enumeration/diagnostics use Contents read. These operations support fine-grained PATs and GitHub App user/installation tokens at the API level. A classic user PAT with `repo` is the broad nonpublic path, constrained by the caller's actual access. Enterprise ownership alone does not prove repository access. Maester's current connection requires a user identity and active organization membership; this check does not add installation-token connection support.

#### Impact

The developer workflow depends on the policies repository owners configure in the protection rule. Coordinate those policies and their rollout with each repository owner.

#### Remediation action

1. Identify every in-use repository and the branches covered by this recommendation. Reconcile public, internal, private, archived, and disabled repositories; do not exclude a repository just because it is archived.
2. On [GitHub](https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule), open the repository, then **Settings** > **Branches**. Use your deployment's host when working on GHE.com.
3. Edit the applicable classic branch protection rule, or add one covering the required branch. Add a classic branch protection rule whose pattern applies to the actual default branch and any separately identified main branch. Configure the repository owners' required policies.
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
