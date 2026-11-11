Unmanaged Microsoft accounts can be used to enumerate internal users and initiate unwanted contact. The check is not applicable to GCC, GCC High and DoD tenants; some other tenants may not expose the relevant settings.

Run the check with Microsoft Graph and Teams connected: `Connect-Maester -Service Graph,Teams`.

#### Remediation action

1. In the [Teams admin center](https://admin.teams.microsoft.com), go to **External collaboration** > **External access** > **Policies**.
2. Open **Global (Org-wide default)** and each custom policy.
3. Either turn off contact with unmanaged Microsoft accounts entirely, or allow internal users to initiate contact while turning off inbound chats and external meeting joins from unmanaged accounts.
4. Save and confirm each policy.

#### Related links

* [Manage chat with external Teams users not managed by an organization](https://learn.microsoft.com/microsoftteams/manage-external-access#manage-chat-with-external-teams-users-not-managed-by-an-organization)
* [CISA Teams baseline MS.TEAMS.2.2v2](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/teams.md)

<!--- Results --->
%TestResult%
