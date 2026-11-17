SharePoint, OneDrive, and Teams message attachments SHOULD be scanned for malware.

Files shared through Teams or hosted on SharePoint and OneDrive can deliver malware. Safe Attachments scanning helps detect and block malicious files. This global setting is not covered by the Standard or Strict preset security policies. This check uses the same implementation as [ORCA.158](https://maester.dev/docs/tests/ORCA.158).

#### Remediation action

1. Sign in to the [Microsoft Defender portal](https://security.microsoft.com).
2. Go to **Email & collaboration** > **Policies & rules** > **Threat policies** > **Safe Attachments**.
3. Open the global Safe Attachments settings and enable scanning for SharePoint, OneDrive, and Microsoft Teams.
4. Save the settings.

#### Related links

* [Safe Attachments in Microsoft Defender for Office 365](https://learn.microsoft.com/defender-office-365/safe-attachments-for-spo-odfb-teams-about)
* [CISA Security Suite baseline - MS.SECURITYSUITE.1.4v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite14v1)

<!--- Results --->
%TestResult%
