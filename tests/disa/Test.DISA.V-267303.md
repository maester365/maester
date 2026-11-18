The Microsoft 365 idle session timeout signs users out after 15 minutes of inactivity or less. (DISA Microsoft Intune MDM Service Desktop STIG, V-267303, CAT II).

A session left open on an unattended computer can be used by anyone who sits down at it. The Intune admin center follows the idle session timeout of Microsoft 365.

The newer Intune MDM STIG has the same rule, so this test runs [DISA.V-273867](https://maester.dev/docs/tests/DISA.V-273867): the idle session timeout must be 15 minutes or less.

#### Remediation action

1. In the [Microsoft 365 admin center](https://admin.microsoft.com), go to **Settings** > **Org settings** > **Security & privacy** > **[Idle session timeout](https://admin.microsoft.com/#/Settings/SecurityPrivacy/:/Settings/L1/IdleSessionTimeout)**.
2. Turn on **Turn on to set the period of inactivity for users to be signed off of Microsoft 365 web apps**.
3. Choose **Custom**, set the period to **15 minutes** and select **Save**.

#### Related links

* [DISA Microsoft Intune MDM Service Desktop STIG: V-267303](https://cyber.trackr.live/stig/Intune_Service_Desktop/1/1/V-267303)
* [Idle session timeout for Microsoft 365](https://learn.microsoft.com/microsoft-365/admin/manage/idle-session-timeout-web-apps)

<!--- Results --->
%TestResult%
