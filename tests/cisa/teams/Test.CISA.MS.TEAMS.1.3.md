Automatically admitting anonymous or dial-in participants reduces control over meeting participation. This check evaluates the Global policy, requiring that not everyone is admitted automatically and that dial-in callers cannot bypass the lobby.

#### Remediation action

1. In the [Teams admin center](https://admin.teams.microsoft.com), go to **Meetings** > **Meeting policies** > **Global (Org-wide default)**.
2. Under **Meeting join and lobby**, set **Who can bypass the lobby** to a value other than **Everyone**.
3. Turn off **People dialing in can bypass the lobby**.
4. Save the policy.

##### PowerShell

Run `Set-CsTeamsMeetingPolicy -Identity Global -AutoAdmittedUsers EveryoneInCompany -AllowPSTNUsersToBypassLobby $false`.

#### Related links

* [Manage meeting policies in Microsoft Teams](https://learn.microsoft.com/microsoftteams/meeting-policies-in-teams)
* [CISA Teams baseline MS.TEAMS.1.3v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/teams.md)

<!--- Results --->
%TestResult%
