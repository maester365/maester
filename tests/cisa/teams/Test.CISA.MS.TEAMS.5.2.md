Third-party Teams apps can introduce vulnerabilities and access paths that the agency does not manage. The check evaluates the unified org-wide app setting when available and otherwise checks all legacy app permission policies.

Connect to Microsoft Graph and Teams before running this check (`Connect-Maester -Service Graph,Teams`). Delegated authentication enables the unified settings API; use `-UseDeviceCode` with `Connect-Maester` when device-code sign-in is required. App-only authentication and unsupported environments use legacy policies.

#### Remediation action

1. In the [Teams admin center](https://admin.teams.microsoft.com), go to **Teams apps** > **Manage apps** > **Actions** > **Org-wide app settings**.
2. Turn off third-party apps by default.
3. Review third-party app availability and allow only apps approved by the agency.
4. Save the settings.

#### Related links

* [Use app permission policies to control user access to apps](https://learn.microsoft.com/microsoftteams/teams-app-permission-policies)
* [CISA Teams baseline MS.TEAMS.5.2v2](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/teams.md)

<!--- Results --->
%TestResult%
