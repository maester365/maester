This test checks for Windows Feature Update policies referencing unsupported Windows build versions.
Additional information about Feature Update Policies: [Microsoft learn - Feature updates for Windows 10 and later policy in Intune](https://learn.microsoft.com/en-us/intune/intune-service/protect/windows-10-feature-updates).


#### Remediation action

1. Visit the Intune Portal [Windows updates blade for feature updates](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/windows10Update)
2. Edit the affected feature update policy and select a supported Windows 11 OS version, save the policy.

<!--- Results --->
%TestResult%