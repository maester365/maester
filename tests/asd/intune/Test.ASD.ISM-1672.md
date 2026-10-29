Microsoft Office macro antivirus scanning is enabled (ISM-1672, Essential Eight Maturity Level One).

A macro that is allowed to run can still be malicious. With macro runtime scanning, Office hands the behaviour of a running macro to the Antimalware Scan Interface (AMSI), where Microsoft Defender Antivirus or another registered antivirus inspects it and stops it. This check reads the Intune settings catalog policies for Windows and looks for **Macro Runtime Scan Scope** set to **Enabled** with the scope **Enable for all documents**, in an assigned policy. ASD's [guide to restricting Microsoft Office macros](https://www.cyber.gov.au/publication/restricting-microsoft-office-macros) and the ASD Blueprint for Secure Cloud both set all documents. **Enable for low trust documents** scans only files with the Mark of the Web, whose macros [ASD.ISM-1488](https://maester.dev/docs/tests/ASD.ISM-1488) already blocks, so it does not count.

The check confirms that a policy has an inclusion assignment. It does not verify assignment coverage or exclusions, conflicting policies, or the effective settings on devices.

#### Remediation action

1. In **Microsoft Intune admin center**, go to **Devices** > **[Configuration](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configuration)** > **Create** > **New policy** > **Windows 10 and later** > **Settings catalog**.
2. Add, under **Microsoft Office 2016** > **Security Settings**, the setting **Macro Runtime Scan Scope**, set it to **Enabled** and choose **Enable for all documents**.
3. Assign the policy to all users.

#### Related links

* [Essential Eight maturity model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [ASD Microsoft Office macro security](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/microsoft-office-macro-security)
* [Antimalware Scan Interface (AMSI)](https://learn.microsoft.com/windows/win32/amsi/antimalware-scan-interface-portal)

<!--- Results --->
%TestResult%
