Enable Shell Task Validation to prevent code injection.

Rationale: Code injection through arguments parameters should be prevented.

#### Remediation action:
Enable the policy to stop these requests and notifications.
1. Sign in to your organization
2. Choose Organization settings.
3. Select Settings under Pipelines.
4. Go to the section "Task restrictions" and turn on "Enable shell tasks arguments validation"

**Results:**
This validation applies to the arguments parameter in the following specific tasks:
- PowerShell
- BatchScript
- Bash
- Ssh
- AzureFileCopy
- WindowsMachineFileCopy

#### Related links

* [Learn - Shell Tasks Validation](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/inputs?view=azure-devops#shellTasksValidation)
