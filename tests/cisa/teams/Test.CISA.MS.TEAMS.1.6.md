Meeting recordings can disclose confidential discussions, shared screens and personal information. This check reuses `CIS.M365.8.5.9` because both suites evaluate whether cloud recording is disabled in the Global meeting policy.

#### Remediation action

1. In the [Teams admin center](https://admin.teams.microsoft.com), go to **Meetings** > **Meeting policies** > **Global (Org-wide default)**.
2. Under **Recording & transcription**, turn off **Meeting recording**.
3. Save the policy.

##### PowerShell

Run `Set-CsTeamsMeetingPolicy -Identity Global -AllowCloudRecording $false`.

#### Related links

* [Manage meeting policies in Microsoft Teams](https://learn.microsoft.com/microsoftteams/meeting-policies-in-teams)
* [CIS Microsoft 365 Foundations Benchmark, control 8.5.9](https://www.cisecurity.org/benchmark/microsoft_365)
* [CISA Teams baseline MS.TEAMS.1.6v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/teams.md)

<!--- Results --->
%TestResult%
