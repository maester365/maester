Internet Explorer 11 is disabled or removed (ISM-1654, Essential Eight Maturity Level One).

Internet Explorer 11 is out of support and keeps the legacy rendering engine and ActiveX reachable from the desktop. This check reads the Intune settings catalog policies for Windows and looks for **Disable Internet Explorer 11 as a standalone browser** set to **Enabled** in an assigned policy. Removing the Internet Explorer optional feature also meets the control; the [ASD Blueprint for Secure Cloud](https://blueprint.asd.gov.au/configuration/intune/devices/scripts/userapplicationhardening-removefeatures/) does it with a platform script. Maester cannot read platform scripts, so if you rely on removal, turn this test off in `maester-config.json` (`TestSettings`, `Enabled: false`, with the reason). ASD's assessment process guide also asks for an application control rule that blocks `iexplore.exe`, because standard users can still start it, even on Windows 11.

The check confirms that a policy has an inclusion assignment. It does not verify assignment coverage or exclusions, conflicting policies, or the effective settings on devices.

#### Remediation action

1. In **Microsoft Intune admin center**, go to **Devices** > **[Configuration](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configuration)** > **Create** > **New policy** > **Windows 10 and later** > **Settings catalog**.
2. Add, under **Administrative Templates** > **Windows Components** > **Internet Explorer**, the setting **Disable Internet Explorer 11 as a standalone browser** and set it to **Enabled**.
3. Assign the policy to all devices.

#### Related links

* [Essential Eight maturity model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [Disable Internet Explorer 11 as a standalone browser](https://learn.microsoft.com/deployedge/edge-ie-disable-ie11)

<!--- Results --->
%TestResult%
