Ensure at least one **assigned** Android app protection policy keeps organization data inside managed apps.

**This is the control a device compliance policy cannot provide.** A tenant can require a compliant, locked, up-to-date Android phone and still let a user share an attachment from Outlook into a personal cloud drive, paste a customer list into a note-taking app, or let the Google backup copy the app's data to a personal account. Compliance evaluates the device; app protection evaluates what the app may do with the data.

Four settings decide whether organization data can leave the managed boundary:

- **Send org data to other apps** (`allowedOutboundDataTransferDestinations`) must be **Policy managed apps** or **None**, not **All apps**.
- **Cut, copy and paste with other apps** (`allowedOutboundClipboardSharingLevel`) must not be **Any app**.
- **Save copies of org data** (`saveAsBlocked`) must be **Block**.
- **Backup org data to Android backup services** (`dataBackupBlocked`) must be **Block**.

Any one of them left open is a route out, so all four are read from the **same** policy.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an app protection policy with no assignment is never applied to a user.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Apps** > **App protection policies**.
3. Select an existing **Android** policy, or select **+ Create policy** and choose **Android**.
4. Under **Data protection** > **Data transfer**, set **Send org data to other apps** to **Policy managed apps**.
5. Set **Save copies of org data** to **Block** (add only the organization locations you need under **Allow user to save copies to selected services**).
6. Set **Cut, copy and paste with other apps** to **Policy managed apps** or **Policy managed apps with paste in**.
7. Set **Backup org data to Android backup services** to **Block**.
8. On the **Assignments** tab, assign the policy to the user groups whose apps hold organization data.
9. Select **Next** and then **Create** or **Save**.

The Intune data protection framework publishes these values as part of its enterprise basic, enhanced and high data protection levels; the related link below gives the full set per level.

#### Related links

- [Microsoft Learn - Data protection framework using app protection policies](https://learn.microsoft.com/intune/app-management/protection/data-protection-framework)
- [Microsoft Learn - Android app protection policy settings](https://learn.microsoft.com/intune/app-management/protection/ref-settings-android)
- [Microsoft Learn - Apps protected by Intune](https://learn.microsoft.com/intune/app-management/ref-protected-apps)

<!--- Results --->
%TestResult%
