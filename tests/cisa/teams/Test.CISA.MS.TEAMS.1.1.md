An external participant who can request control of a shared screen may perform unauthorized actions during a meeting. This check evaluates the Global meeting policy and every custom policy.

#### Remediation action

1. In the [Teams admin center](https://admin.teams.microsoft.com), go to **Meetings** > **Meeting policies**.
2. Open the **Global (Org-wide default)** policy and each custom policy.
3. Under **Content sharing**, turn off **External participants can give or request control**.
4. Save each policy.

##### PowerShell

Run `Set-CsTeamsMeetingPolicy -Identity <PolicyIdentity> -AllowExternalParticipantGiveRequestControl $false` for the Global policy and each affected custom policy.

#### Related links

* [Manage meeting policies in Microsoft Teams](https://learn.microsoft.com/microsoftteams/meeting-policies-in-teams)
* [CISA Teams baseline MS.TEAMS.1.1v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/teams.md)

<!--- Results --->
%TestResult%
