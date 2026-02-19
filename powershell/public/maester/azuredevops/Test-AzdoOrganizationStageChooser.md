Users SHOULD NOT be able to skip stages defined by the pipeline author.

Rationale: Users should not be able to select stages to skip from the Queue Pipeline panel.

#### Remediation action:
Disable the policy to stop these requests and notifications.
1. Sign in to your organization
2. Choose Organization settings.
3. Select Settings under Pipelines, locate the "Disable stage chooser" policy and toggle it to on.

#### Related links

* [Learn - Stages](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/stages?view=azure-devops&tabs=yaml)
* [Learn - Azure DevOps pipeline security](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops)
