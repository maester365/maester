User defined variables SHOULD NOT be able to override system variables or variables not defined by the pipeline author.

Rationale: Only those variables explicitly marked as "Settable at queue time" can be set by user.

#### Remediation action:
Enable the policy to limit variables that can be set at queue time.
1. Sign in to your organization
2. Choose Organization settings.
3. Under the Pipelines section choose Settings.
4. In the General section, toggle on "Limit variables that can be set at queue time".

**Results:**
Only those variables explicitly marked as "Settable at queue time" can be set at queue time.

#### Related links

* [Learn - Secure use of variables in a pipeline](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/inputs?view=azure-devops#limit-variables-that-can-be-set-at-queue-time)
