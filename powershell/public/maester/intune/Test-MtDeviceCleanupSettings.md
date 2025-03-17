Ensure device clean-up rule is configured

This test checks if the device clean-up rule is configured.

Set your Intune device cleanup rules to delete Intune MDM enrolled devices that appear inactive, stale, or unresponsive. Intune applies cleanup rules immediately and continuously so that your device records remain current.

#### Remediation action:

To enable device clean-up rules:
1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).
2. Click **Devices** scroll down to **Organize devices**.
3. Select **Device clean-up rules**.
4. Set **Delete devices based on last check-in date** to **Yes**
5. Set **Delete devices that haven’t checked in for this many days** to **30 days or more** depending on your organizational needs.
6. Click **Save**.

#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [Microsoft Intune - Device clean-up rules](https://intune.microsoft.com/?ref=AdminCenter#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/deviceCleanUp)

<!--- Results --->
%TestResult%