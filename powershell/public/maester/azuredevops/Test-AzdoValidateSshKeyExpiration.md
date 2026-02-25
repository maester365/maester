Validation of SSH key expiration date **should be** enabled.

Rationale: Expired SSH keys should not be valid for authentication towards Azure DevOps.

#### Remediation action:
Enable the policy to stop these requests and notifications.
1. Sign in to your organization.
2. Choose Organization settings.
3. Select Policies under Security.
4. Switch the Validate SSH key expiration button to ON.

**Results:**
When active, Azure DevOps enforces that the expiration for date-expired keys immediately become invalid for authentication.

#### Related links

* [Learn - SSH key policies](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/change-application-access-policies?view=azure-devops#ssh-key-policies)
* [Learn - My SSH key has expired, what should I do?](https://learn.microsoft.com/en-us/azure/devops/repos/git/use-ssh-keys-to-authenticate?view=azure-devops#q-my-ssh-key-has-expired-what-should-i-do)
