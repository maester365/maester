Automatically admitting internal participants avoids requiring them to wait for admission. This check evaluates the Global meeting policy and accepts only values that automatically admit internal users.

#### Remediation action

1. In the [Teams admin center](https://admin.teams.microsoft.com), go to **Meetings** > **Meeting policies** > **Global (Org-wide default)**.
2. Under **Meeting join and lobby**, set **Who can bypass the lobby** to **People in my org** (`EveryoneInCompanyExcludingGuests`).
3. Save the policy.

The CISA check also accepts `EveryoneInCompany` and `EveryoneInSameAndFederatedCompany`. If you also follow CIS 8.5.3, use `EveryoneInCompanyExcludingGuests`: `EveryoneInCompany` includes guests and fails CIS 8.5.3, while CIS's `InvitedUsers` setting does not automatically admit internal users and fails this CISA check.

##### PowerShell

Run `Set-CsTeamsMeetingPolicy -Identity Global -AutoAdmittedUsers EveryoneInCompanyExcludingGuests`.

#### Related links

* [Manage meeting policies in Microsoft Teams](https://learn.microsoft.com/microsoftteams/meeting-policies-in-teams)
* [CISA Teams baseline MS.TEAMS.1.4v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/teams.md)

<!--- Results --->
%TestResult%
