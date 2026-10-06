Dial-in users should not be able to bypass the meeting lobby.

Dial-in users aren’t authenticated though the Teams app. Increase the security of your meetings by preventing these unknown users from bypassing the lobby and immediately joining the meeting.

This test checks the `AllowPSTNUsersToBypassLobby` setting of the Global (Org-wide default) Teams meeting policy.

#### Remediation action

1. Open [Meeting policies](https://admin.teams.microsoft.com/policies/meetings) in the Teams admin center.
2. Select the **Global (Org-wide default)** policy.
3. Set **People dialing in can bypass the lobby** to **Off**.
4. Select **Save**.

Or with PowerShell: `Set-CsTeamsMeetingPolicy -Identity Global -AllowPSTNUsersToBypassLobby $false`

#### Related links

* [Manage meeting policies in Microsoft Teams - Microsoft Learn](https://learn.microsoft.com/microsoftteams/meeting-policies-overview)

<!--- Results --->
%TestResult%
