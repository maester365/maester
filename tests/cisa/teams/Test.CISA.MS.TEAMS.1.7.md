Setting live event recording to always record can capture sensitive content without the organizer's discretion. This check evaluates the Global meeting broadcast policy and fails only when recording is set to **Always record**.

#### Remediation action

1. In the [Teams admin center](https://admin.teams.microsoft.com), go to **Meetings** > **Live events policies** > **Global (Org-wide default)**.
2. Set **Record an event** to **Organizer can record** or **Never record**.
3. Save the policy.

##### PowerShell

Run `Set-CsTeamsMeetingBroadcastPolicy -Identity Global -BroadcastRecordingMode UserOverride` or set the mode to `AlwaysDisabled`.

#### Related links

* [Manage live events policies in Microsoft Teams](https://learn.microsoft.com/microsoftteams/teams-live-events/plan-for-teams-live-events)
* [CISA Teams baseline MS.TEAMS.1.7v2](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/teams.md)

<!--- Results --->
%TestResult%
