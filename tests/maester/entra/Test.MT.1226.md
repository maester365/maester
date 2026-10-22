This test identifies application federated identity credentials for GitHub Actions and GitLab whose subjects appear to use mutable identifiers instead of immutable IDs.

Repository names, project paths and organization names can change or be reused. A credential that continues trusting a reused name can grant access to a different workload. Microsoft calls this subject recycling. Dangling credentials are particularly exposed because their trust remains configured after the original workload is gone.

The check examines the issuer and subject of application federated identity credentials:

* GitHub Actions: Reports subjects that do not start with `repo:<username>@<userid>/<repo>@<repoid>:`, with numeric owner and repository IDs.
* GitLab: Reports subjects without project_id:, which identifies the immutable project ID.

The test fails when at least one evaluated credential lacks the corresponding immutable identifier marker.

#### Remediation action

For each reported credential:

1. Confirm that the trusted repository or project still exists and requires access. Delete credentials for workloads that are no longer used.
2. For GitHub Actions, create a credential matching the immutable owner and repository IDs, then enable immutable subjects in the repository or organization OIDC settings.
3. For GitLab, configure `ci_id_token_sub_claim_components` to use `project_id` instead of `project_path`, and update the federated credential to match.
4. Validate pipeline authentication before removing the old name-based credential.

#### Related links

- [Mutable subjects in federated identity credentials](https://learn.microsoft.com/entra/workload-id/workload-identities-federated-credential-mutable-subjects)
- [Migrate GitHub Actions federated credentials to immutable subjects](https://learn.microsoft.com/entra/workload-id/workload-identities-github-immutable-subjects)

<!--- Results --->
%TestResult%
