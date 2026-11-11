Teams channel email integration can allow untrusted email content to be delivered into channels. This check reuses `CIS.M365.8.1.2` for the Global client configuration. Availability may vary by Microsoft 365 environment and tenant.

#### Remediation action

1. In the [Teams admin center](https://admin.teams.microsoft.com), go to **Teams** > **Teams settings**.
2. Under **Email integration**, turn off **Users can send emails to a channel email address**.
3. Clear any entries in **Accept channel email from these SMTP domains**.
4. Save the settings.

##### PowerShell

Run `Set-CsTeamsClientConfiguration -Identity Global -AllowEmailIntoChannel $false`.

#### Related links

* [Email integration in Teams](https://learn.microsoft.com/microsoftteams/settings-policies-reference#email-integration)
* [CIS Microsoft 365 Foundations Benchmark, control 8.1.2](https://www.cisecurity.org/benchmark/microsoft_365)
* [CISA Teams baseline MS.TEAMS.4.1v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/teams.md)

<!--- Results --->
%TestResult%
