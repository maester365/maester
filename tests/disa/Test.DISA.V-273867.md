The Microsoft 365 idle session timeout signs users out of Microsoft 365 web apps after 15 minutes of inactivity or less (DISA Microsoft Intune MDM Service Desktop and Mobile STIG, V-273867, CAT II).

A browser session left open on an unattended computer can be used by anyone who sits down at it. The idle session timeout signs a user out of Outlook on the web, SharePoint, OneDrive and the other Microsoft 365 web apps, including the admin centers, after a period without activity. DISA asks for 15 minutes or less, which is shorter than the CIS benchmark's three hours.

The setting is stored as the tenant's activity-based timeout policy. Its check (`MaximumIdleTimeoutMinutes`, 15 by default) passes when that policy sets a timeout of no more than the allowed number of minutes. [CIS.M365.1.3.2](https://maester.dev/docs/tests/CIS.M365.1.3.2) reads the same policy with a limit in hours and also requires a Conditional Access policy for unmanaged devices, which this STIG does not ask for.

#### Remediation action

1. In the [Microsoft 365 admin center](https://admin.microsoft.com), go to **Settings** > **Org settings** > **Security & privacy** > **[Idle session timeout](https://admin.microsoft.com/#/Settings/SecurityPrivacy/:/Settings/L1/IdleSessionTimeout)**.
2. Turn on **Turn on to set the period of inactivity for users to be signed off of Microsoft 365 web apps**.
3. Choose **Custom** and set the period to **15 minutes**.
4. Select **Save**.

#### Related links

* [DISA Microsoft Intune MDM Service Desktop and Mobile STIG: V-273867](https://cyber.trackr.live/stig/Intune_MDM_Service_Desktop_&_Mobile/1/2/V-273867)
* [Idle session timeout for Microsoft 365](https://learn.microsoft.com/microsoft-365/admin/manage/idle-session-timeout-web-apps)

<!--- Results --->
%TestResult%
