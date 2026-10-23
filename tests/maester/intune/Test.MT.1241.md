Ensure at least one **assigned** iOS app protection policy requires a minimum OS and app version.

On an unenrolled phone, the **conditional launch** rules of an app protection policy are the only lever the organization has over how old the platform underneath its data is allowed to be. There is no compliance evaluation, no update ring and no device inventory: either the policy refuses to open the app on an outdated iOS or app version, or it does not.

Two versions matter:

- **Min OS version** (`minimumRequiredOsVersion`) is the platform whose protections the whole app protection model rests on.
- **Min app version** (`minimumRequiredAppVersion`) is the app carrying the Intune App SDK that enforces the policy. An app old enough can predate the settings the policy relies on.

Both are optional free-text fields in Intune, and both come back empty when they were never configured. This test checks that a floor was set, not which floor: the right value depends on the organization's fleet, and the Intune data protection framework recommends following the current Apple support policy, typically the latest major version or the one before it.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an app protection policy with no assignment is never applied to a user.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Apps** > **App protection policies**.
3. Select an existing **iOS** policy, or select **+ Create policy** and choose **iOS**.
4. Under **Conditional launch** > **Device conditions**, add **Min OS version** and set the oldest iOS version you support, with the action **Block access** or **Warn**.
5. Under **Conditional launch** > **App conditions**, add **Min app version** and set the oldest app version you support.
6. On the **Assignments** tab, assign the policy to the user groups whose apps hold organization data.
7. Select **Next** and then **Create** or **Save**.

Review these floors on a schedule. A minimum version set once and never raised stops being a control as the fleet moves on.

#### Related links

- [Microsoft Learn - iOS app protection policy settings](https://learn.microsoft.com/intune/app-management/protection/ref-settings-ios)
- [Microsoft Learn - Data protection framework using app protection policies](https://learn.microsoft.com/intune/app-management/protection/data-protection-framework)
- [Microsoft Learn - Create and assign app protection policies](https://learn.microsoft.com/intune/app-management/protection/create-policy)

<!--- Results --->
%TestResult%
