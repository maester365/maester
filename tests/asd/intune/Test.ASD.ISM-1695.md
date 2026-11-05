Patches, updates or other vendor mitigations for vulnerabilities in the operating systems of workstations are applied within one month of release (ISM-1695, Essential Eight Maturity Level One).

A workstation that defers quality updates with no deadline installs them when the user chooses, which may be never. A Windows update ring with a deadline configures when installation and restart become compulsory. This check reads the update rings in Intune and passes when at least one ring with an inclusion assignment does not pause quality updates, sets a deadline, and the deferral period, deadline and grace period add up to no more than 30 days (the `MaximumDays` parameter). It does not verify the assignment coverage or exclusions, policy conflicts, or actual installation on devices. A device can discover an update after its release, so the configured total does not establish the time from release to installation. Rings managed by Windows Autopatch, or devices patched by another tool, are not read.

#### Remediation action

1. In **Microsoft Intune admin center**, go to **Devices** > **Windows** > **[Update rings for Windows 10 and later](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/windowsUpdate)** and open the ring assigned to your workstations, or create one.
2. Under **Update settings**, set **Quality update deferral period (days)** to a small value, 0 to 7.
3. Under **Deadline settings**, set **Use deadline settings** to **Allow**, **Deadline for quality updates** to a value that keeps deferral, deadline and grace period within 30 days (for example 7), and **Grace period** to 2.
4. Assign the ring to all workstations.

#### Related links

* [Essential Eight maturity model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [ASD Patching applications and operating systems](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/patching-applications-and-operating-systems)
* [Windows update rings policy in Intune](https://learn.microsoft.com/intune/intune-service/protect/windows-update-for-business-configure)

<!--- Results --->
%TestResult%
