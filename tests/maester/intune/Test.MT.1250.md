Ensure at least one **assigned** Android app protection policy blocks screen capture of organization data.

A screenshot is a copy of organization data that leaves through **none** of the data transfer paths a policy restricts. It lands in the device gallery, which on a personal phone is usually syncing to a personal cloud account, and it is readable by any app the user has granted storage or screen-recording access to.

Blocking screen capture (`screenCaptureBlocked`) sets the platform flag that also hides the app's content from Android screen recording and from the recent-apps preview. It is the only setting in the app protection model that the platform enforces for the whole app window rather than for a single copy action.

**This check exists only for Android**, because `screenCaptureBlocked` is an Android-only property. The iOS policy type carries a newer `screenCaptureConfigurationState` alongside the Apple Intelligence settings, but it is optional in the beta schema and its behaviour is not verified here, so no iOS counterpart is claimed.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an app protection policy with no assignment is never applied to a user.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Apps** > **App protection policies**.
3. Select an existing **Android** policy, or select **+ Create policy** and choose **Android**.
4. Under **Data protection** > **Data transfer**, set **Screen capture and Google Assistant** to **Block**.
5. On the **Assignments** tab, assign the policy to the user groups whose apps hold organization data.
6. Select **Next** and then **Create** or **Save**.

This setting is visible to users: screenshots of the managed apps stop working, and the app window goes blank in the recent-apps list. Communicate it before rolling it out.

#### Related links

- [Microsoft Learn - Android app protection policy settings](https://learn.microsoft.com/intune/app-management/protection/ref-settings-android)
- [Microsoft Learn - Data protection framework using app protection policies](https://learn.microsoft.com/intune/app-management/protection/data-protection-framework)
- [Microsoft Learn - App protection policies overview](https://learn.microsoft.com/intune/app-management/protection/overview)

<!--- Results --->
%TestResult%
