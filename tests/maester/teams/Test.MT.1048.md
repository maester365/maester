External participants should not be able to give or request control in Teams meetings.

External participants are users that are outside your organization. Limiting their permission to share content, add new users, and more protects your organization’s information from data leaks, inappropriate content being shared, or malicious actors joining the meeting.

This test checks the `AllowExternalParticipantGiveRequestControl` setting of the Global (Org-wide default) Teams meeting policy.

#### Remediation action

1. Open [Meeting policies](https://admin.teams.microsoft.com/policies/meetings) in the Teams admin center.
2. Select the **Global (Org-wide default)** policy.
3. Set **External participants can give or request control** to **Off**.
4. Select **Save**.

Or with PowerShell: `Set-CsTeamsMeetingPolicy -Identity Global -AllowExternalParticipantGiveRequestControl $false`

#### Related links

* [Manage meeting policies in Microsoft Teams - Microsoft Learn](https://learn.microsoft.com/microsoftteams/meeting-policies-overview)

<!--- Results --->
%TestResult%
