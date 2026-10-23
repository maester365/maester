Ensure at least one **assigned** Android app protection policy limits offline access to organization data.

Every revocation an administrator can perform on an unenrolled phone travels through the app protection check: disabling the account, removing the user from the assigned group, or issuing a selective wipe. The **offline grace period** is how long the managed app keeps opening organization data without that check, and a device kept in airplane mode is a device that has received none of those decisions.

Two settings bound it:

- **Offline grace period** (`periodOfflineBeforeAccessCheck`) blocks access until the app can check in again.
- **Offline grace period / wipe** (`periodOfflineBeforeWipeIsEnforced`) removes the organization's data from a device that never comes back.

This test asks for at most **12 hours** before access is blocked and at most **90 days** before the data is wiped, the values the Intune data protection framework publishes for enterprise data protection.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an app protection policy with no assignment is never applied to a user.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Apps** > **App protection policies**.
3. Select an existing **Android** policy, or select **+ Create policy** and choose **Android**.
4. Under **Conditional launch** > **App conditions**, add **Offline grace period** with the action **Block access** and a value of **720** minutes (12 hours) or less.
5. Add a second **Offline grace period** condition with the action **Wipe data** and a value of **90** days or less.
6. On the **Assignments** tab, assign the policy to the user groups whose apps hold organization data.
7. Select **Next** and then **Create** or **Save**.

Both values are stored as ISO 8601 durations. A value of zero means the condition exists but bounds nothing, so this test requires a positive value as well as one under the limit.

#### Related links

- [Microsoft Learn - Data protection framework using app protection policies](https://learn.microsoft.com/intune/app-management/protection/data-protection-framework)
- [Microsoft Learn - Android app protection policy settings](https://learn.microsoft.com/intune/app-management/protection/ref-settings-android)
- [Microsoft Learn - App protection policies overview](https://learn.microsoft.com/intune/app-management/protection/overview)

<!--- Results --->
%TestResult%
