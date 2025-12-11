Azure DevOps pipelines SHOULD NOT automatically build on every pull request and commit from a GitHub repository.

Rationale: Code should not be automatically built from GitHub.

#### Remediation action:
Enable the policy to stop building from GitHub repositories.
1. Sign in to your organization
2. Choose Organization settings.
3. Select Settings under Pipelines.
4. Go to the section "Triggers" and turn on "Limit building pull requests from forked GitHub repositories"

#### Related links

* [Learn - Validate contributions from forks](https://learn.microsoft.com/en-us/azure/devops/pipelines/repos/github?view=azure-devops&tabs=yaml#validate-contributions-from-forks)
