Disable the ability to install and run tasks from the Marketplace, which gives you greater control over the code that executes in a pipeline.

Rationale: Tasks from marketplace should be reviewed and approved.

#### Remediation action:
Disable the policy to stops these requests and notifications.
1. Sign in to your organization
2. Choose Organization settings.
3. Select Settings under Pipelines.
4. Go to the section "Task restrictions" and turn on "Disable marketplace tasks"

**Results:**
With this enabled, pipelines will not use tasks installed from the Marketplace. Jobs which depend on Marketplace tasks will fail.

#### Related links

* [Learn - Prevent malicious code execution](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops#prevent-malicious-code-execution)
