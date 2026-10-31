Microsoft Office macros in files originating from the internet are blocked (ISM-1488, Essential Eight Maturity Level One).

A macro in an email attachment or a downloaded document is still the most common way malicious code reaches a workstation. Office marks files from the internet with the Mark of the Web and, since 2022, blocks their macros by default; but a user can still unblock a file from its properties, and a Trust Center change can turn the default off. This policy makes the block a tenant decision that the user cannot undo, which is why it is rated as a second layer behind the Office default. This check reads the Intune settings catalog policies for Windows and looks for **Block macros from running in Office files from the Internet** set to **Enabled** for Word, Excel and PowerPoint in an assigned policy. Access, Visio, Project and Publisher are reported when configured. Settings deployed by Group Policy or the Office cloud policy service are not read.

The check confirms that a policy has an inclusion assignment. It does not verify assignment coverage or exclusions, conflicting policies, or the effective settings on devices.

#### Remediation action

1. In **Microsoft Intune admin center**, go to **Devices** > **[Configuration](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configuration)** > **Create** > **New policy** > **Windows 10 and later** > **Settings catalog**.
2. Add, under **Microsoft Word 2016** > **Word Options** > **Security** > **Trust Center**, the setting **Block macros from running in Office files from the Internet** and set it to **Enabled**. Repeat for **Microsoft Excel 2016**, **Microsoft PowerPoint 2016**, and for Access, Visio, Project and Publisher where they are installed.
3. Assign the policy to all users.

#### Related links

* [Essential Eight maturity model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [ASD Microsoft Office macro security](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/microsoft-office-macro-security)
* [Macros from the internet are blocked by default in Office](https://learn.microsoft.com/deployoffice/security/internet-macros-blocked)

<!--- Results --->
%TestResult%
