Access to repositories in YAML pipelines SHOULD apply checks and approval before accessing repositories.

Rationale: To enhance security, consider separating your projects, using branch policies, and adding more security measures for forks. Minimize the scope of service connections and use the most secure authentication methods.

#### Remediation action:
Enable the policy to apply checks and approvals.
1. Sign in to your organization
2. Choose Organization settings.
3. Under the Pipelines section choose Settings.
4. In the General section, toggle on "Protect access to repositories in YAML pipelines".

**Results:**
Apply checks and approvals when accessing repositories from YAML pipelines. Also, generate a job access token that is scoped to repositories that are explicitly referenced in the YAML pipeline.

#### Related links

* [Learn - Restrict project, repository, and service connection access](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops#restrict-project-repository-and-service-connection-access)
