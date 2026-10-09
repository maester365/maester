Only invited users should be automatically admitted to Teams meetings.

Users who aren’t invited to a meeting shouldn’t be let in automatically, because it increases the risk of data leaks, inappropriate content being shared, or malicious actors joining. If only invited users are automatically admitted, then users who weren’t invited will be sent to a meeting lobby. The host can then decide whether or not to let them in.

This test checks the `AutoAdmittedUsers` setting of the Global (Org-wide default) Teams meeting policy.

#### Remediation action

1. Open [Meeting policies](https://admin.teams.microsoft.com/policies/meetings) in the Teams admin center.
2. Select the **Global (Org-wide default)** policy.
3. Set **Who can bypass the lobby** to **People who were invited**.
4. Select **Save**.

Or with PowerShell: `Set-CsTeamsMeetingPolicy -Identity Global -AutoAdmittedUsers InvitedUsers`

#### Related links

* [Manage meeting policies in Microsoft Teams - Microsoft Learn](https://learn.microsoft.com/microsoftteams/meeting-policies-overview)

<!--- Results --->
%TestResult%
