Disable Node 6 tasks.

#### Remediation action:
Disable the policy to stops these requests and notifications.
1. Sign in to your organization
2. Choose Organization settings.
3. Select Settings under Pipelines.
4. Go to the section "Task restrictions" and turn on "Disable Node 6 tasks"

**Results:**
With this enabled, pipelines will fail if they utilize a task with a Node 6 execution handler.

#### Related links

* [Learn - Prevent malicious code execution](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops#prevent-malicious-code-execution)
* [Learn - Remove Node 6 and Node 10 runners from Microsoft-hosted agents](https://learn.microsoft.com/en-us/azure/devops/release-notes/roadmap/2022/no-node-6-on-hosted-agents)
