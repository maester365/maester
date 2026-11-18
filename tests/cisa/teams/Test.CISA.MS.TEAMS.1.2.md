Anonymous participants who can start a meeting can create meetings without an authenticated organizer. This check evaluates the Global meeting policy and all custom meeting policies.

#### Remediation action

1. In the [Teams admin center](https://admin.teams.microsoft.com), go to **Meetings** > **Meeting policies**.
2. Open the **Global (Org-wide default)** policy and each custom policy.
3. Under **Meeting join and lobby**, turn off **Anonymous users and dial-in callers can start a meeting**.
4. Save each policy.

##### PowerShell

Run `Set-CsTeamsMeetingPolicy -Identity <PolicyIdentity> -AllowAnonymousUsersToStartMeeting $false` for the Global policy and each affected custom policy.

#### Related links

* [Manage meeting policies in Microsoft Teams](https://learn.microsoft.com/microsoftteams/meeting-policies-in-teams)
* [CISA Teams baseline MS.TEAMS.1.2v2](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/teams.md)

<!--- Results --->
%TestResult%
