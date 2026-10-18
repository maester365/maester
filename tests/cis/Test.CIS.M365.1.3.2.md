Browser sessions on unmanaged devices for Microsoft 365 apps end after at most three hours of inactivity.

A browser that someone leaves open on a shared or personal computer keeps the Microsoft 365 session signed in. Anyone who walks up to it, or any malware that runs on it, can use the session. A short idle timeout signs the user out of the web apps when nothing happens for a while.

Two parts are needed: an activity-based timeout policy with a web session idle timeout of 3 hours or less, and a Conditional Access policy that uses **Use app enforced restrictions** for browser access to Office 365 so that the timeout applies to unmanaged devices. The test looks at both.

Only emergency access accounts listed in [EmergencyAccessAccounts](https://maester.dev/docs/configuration/emergency-access-accounts) are accepted as exclusions, and a condition that narrows the policy is reported unless the check is about that condition.

#### Remediation action

1. Sign in to the [Microsoft 365 admin center](https://admin.microsoft.com).
2. Go to **Settings** > **Org settings** > **Security & privacy** > [**Idle session timeout**](https://admin.microsoft.com/#/Settings/SecurityPrivacy/:/Settings/L1/IdleSessionTimeout) and turn it on with a timeout of 3 hours or less.
3. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) and go to **Entra ID** > **Conditional Access** > **Policies**.
4. Create a policy for **All users** and the **Office 365** app, with **Client apps** set to **Browser** only. Under **Session**, select **Use app enforced restrictions** and enable the policy.

#### Related links

* [Microsoft 365 admin center - Idle session timeout](https://admin.microsoft.com/#/Settings/SecurityPrivacy/:/Settings/L1/IdleSessionTimeout)
* [Idle session timeout for Microsoft 365](https://learn.microsoft.com/microsoft-365/admin/manage/idle-session-timeout-web-apps)
* [Conditional Access: session controls](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-session)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 1.3.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
