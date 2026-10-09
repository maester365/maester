Anonymous users should not be able to join Teams meetings.

By restricting anonymous users from joining Microsoft Teams meetings, you have full control over meeting access. Anonymous users may not be from your organization and could have joined for malicious purposes, such as gaining information about your organization through conversations.

This test checks the `AllowAnonymousUsersToJoinMeeting` setting of the Global (Org-wide default) Teams meeting policy.

#### Remediation action

1. Open [Meeting policies](https://admin.teams.microsoft.com/policies/meetings) in the Teams admin center.
2. Select the **Global (Org-wide default)** policy.
3. Set **Anonymous users can join a meeting** to **Off**.
4. Select **Save**.

Or with PowerShell: `Set-CsTeamsMeetingPolicy -Identity Global -AllowAnonymousUsersToJoinMeeting $false`

#### Related links

* [Manage meeting policies in Microsoft Teams - Microsoft Learn](https://learn.microsoft.com/microsoftteams/meeting-policies-overview)

<!--- Results --->
%TestResult%
