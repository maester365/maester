Internet Explorer 11 is disabled or removed (ISM-1654, Essential Eight Maturity Level One).

Internet Explorer 11 is out of support and keeps the legacy rendering engine and ActiveX reachable from the desktop. This check reads the Intune settings catalog policies for Windows and looks for **Disable Internet Explorer 11 as a standalone browser** set to **Enabled** in an assigned policy. Devices where Internet Explorer is removed as a Windows optional feature, or that run a Windows release that no longer carries it, satisfy the control without this setting; the check does not see them.

#### Remediation action

1. In **Microsoft Intune admin center**, go to **Devices** > **[Configuration](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configuration)** > **Create** > **New policy** > **Windows 10 and later** > **Settings catalog**.
2. Add, under **Administrative Templates** > **Windows Components** > **Internet Explorer**, the setting **Disable Internet Explorer 11 as a standalone browser** and set it to **Enabled**.
3. Assign the policy to all devices.

#### Related links

* [Essential Eight Maturity Model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [Disable Internet Explorer 11 as a standalone browser](https://learn.microsoft.com/deployedge/edge-ie-disable-ie11)

<!--- Results --->
%TestResult%
