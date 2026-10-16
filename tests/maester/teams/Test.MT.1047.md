Anonymous users should not be able to start Teams meetings.

If anonymous users are allowed to start meetings, they can admit any users from the lobbies, authenticated or otherwise. Anonymous users haven’t been authenticated, which can increase the risk of data leakage.

This test checks the `AllowAnonymousUsersToStartMeeting` setting of the Global (Org-wide default) Teams meeting policy.

#### Remediation action

1. Open [Meeting policies](https://admin.teams.microsoft.com/policies/meetings) in the Teams admin center.
2. Select the **Global (Org-wide default)** policy.
3. Set **Anonymous users and dial-in callers can start a meeting** to **Off**.
4. Select **Save**.

Or with PowerShell: `Set-CsTeamsMeetingPolicy -Identity Global -AllowAnonymousUsersToStartMeeting $false`

#### Related links

* [Manage meeting policies in Microsoft Teams - Microsoft Learn](https://learn.microsoft.com/microsoftteams/meeting-policies-overview)

<!--- Results --->
%TestResult%
