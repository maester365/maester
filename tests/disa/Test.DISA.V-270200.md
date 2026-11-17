Idle sessions are signed out after 15 minutes of inactivity or less. (DISA Microsoft Entra ID STIG, V-270200, CAT II).

A session left open on an unattended computer can be used by anyone who sits down at it. DISA asks Microsoft Entra ID to lock a session after 15 minutes without activity.

The STIG's check reads the directory-level idle timeout of the Azure portal (**Settings** > **Signing out + notifications**), which has no documented API. Microsoft 365 applies its idle session timeout to the Azure portal as well, unless the portal sets its own value, so this test runs [DISA.V-273867](https://maester.dev/docs/tests/DISA.V-273867), which reads that timeout, with a maximum of 15 minutes. Check the portal setting by hand if it is configured there.

#### Remediation action

1. In the [Microsoft 365 admin center](https://admin.microsoft.com), go to **Settings** > **Org settings** > **Security & privacy** > **[Idle session timeout](https://admin.microsoft.com/#/Settings/SecurityPrivacy/:/Settings/L1/IdleSessionTimeout)**.
2. Turn on **Turn on to set the period of inactivity for users to be signed off of Microsoft 365 web apps**.
3. Choose **Custom**, set the period to **15 minutes** and select **Save**.
4. In the [Azure portal](https://portal.azure.com), select the gear icon > **Signing out + notifications**, select **Enable directory level idle timeout** and set it to **15 minutes**.

#### Related links

* [DISA Microsoft Entra ID STIG: V-270200](https://cyber.trackr.live/stig/Entra_ID/1/2/V-270200)
* [Idle session timeout for Microsoft 365](https://learn.microsoft.com/microsoft-365/admin/manage/idle-session-timeout-web-apps)

<!--- Results --->
%TestResult%
