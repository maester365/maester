4.1 (L2) Ensure devices without a compliance policy are marked 'not compliant'

**Rationale:**
Implementing this setting is a first step in adopting compliance policies for devices.
When used in together with Conditional Access policies the attack surface can be reduced by forcing an action to be taken for non-compliant devices.

#### Remediation action:

1. Navigate to Microsoft Intune admin center [https://intune.microsoft.com](https://intune.microsoft.com).
2. Click on **Devices** and then under **Managed devices** on **Compliance**.
3. Click **Compliance settings**.
4. Ensure **Mark devices with no compliance policy assigned as** set to **Not compliant**

#### Related links

* [Microsoft Intune Admin Center | Devices | Compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 156](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%