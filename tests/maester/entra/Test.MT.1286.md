User sponsors of Agent ID objects should have a manager.

Agent identities and Agent Identity Blueprints need an accountable sponsor. When a sponsor leaves or changes roles, the Lifecycle Workflows task **Transfer agent identity sponsorships to manager** adds the sponsor's manager as a sponsor and removes the user. The task requires a populated manager attribute. Without a manager, the sponsorship has nowhere to go when that sponsor leaves. With a disabled manager, it goes to an account nobody uses.

This check reads the sponsors of agent identities, Agent Identity Blueprints and Blueprint Principals. It reports every user sponsor that has no manager, or whose manager is not confirmed as an enabled account: a disabled account, or a manager with no account state, such as a contact. Sponsors that are not users, such as groups, have no manager and are not evaluated.

A manager that is set but no longer the right successor still resolves, and the transfer goes through. This check cannot see that case: review who each sponsor's manager is, not only whether one is set.

### Remediation action:

1. Sign in to the [Microsoft Entra admin center][entra-admin-center] as at least a User Administrator and browse to **Entra ID** > **Users**.
2. Open each reported sponsor, select **Edit properties**, and set **Manager** on the **Job information** tab. For a user synchronized from Active Directory, set the manager in Active Directory instead and wait for the next synchronization.
3. Where the reported manager is a disabled account, set the sponsor's current manager.
4. To transfer sponsorships automatically, create a workflow from the **Transition agent sponsorships when a sponsor leaves** or **Transition agent sponsorships when a sponsor changes roles** template.

### Related links

* [Lifecycle Workflow built-in tasks: Transfer agent identity sponsorships to manager][lcw-task]
* [Agent identity sponsor tasks in Lifecycle Workflows][sponsor-tasks]
* [Governing agent identities][governance]
* [Add or update a user's profile information][user-profile]

[entra-admin-center]: https://entra.microsoft.com
[lcw-task]: https://learn.microsoft.com/entra/id-governance/lifecycle-workflow-tasks#transfer-agent-identity-sponsorships-to-manager
[sponsor-tasks]: https://learn.microsoft.com/entra/id-governance/agent-sponsor-tasks
[governance]: https://learn.microsoft.com/entra/id-governance/agent-id-governance-overview
[user-profile]: https://learn.microsoft.com/entra/fundamentals/how-to-manage-user-profile-info

<!--- Results --->
%TestResult%
