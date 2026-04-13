4.1 (L2) Ensure devices without a compliance policy are marked 'not compliant'

Compliance policies are sets of rules and conditions that are used to evaluate the configuration of managed devices. These policies can help secure organizational data and resources from devices that don't meet those configuration requirements. Managed devices must satisfy the conditions you set in your policies to be considered compliant by Intune. When combined with conditional access, this allows more control over how non-compliant devices are treated.

The recommended state is **Mark devices with no compliance policy assigned as** **Not compliant**

#### Rationale

Implementing this setting is a first step in adopting compliance policies for devices. When used in together with Conditional Access policies the attack surface can be reduced by forcing an action to be taken for non-compliant devices.

>Note: This section does not focus on which compliance policies to use, only that an organization should adopt and enforce them to their needs.

#### Impact

Any devices without a compliance policy will be marked not compliant. Care should be taken to first deploy any new compliance policies with a Conditional Access (CA) policy that is in the Report-only state. After the environment's device compliance is better understood it is then appropriate to finally align with **Mark devices with no compliance policy assigned as** and enable any CA policies that enforce actions based on device compliance.

If a mature environment already has an existing device compliance CA policy and a large number of devices without an assigned compliance policy, this could cause disruption as those devices would then be suddenly considered not compliant.


#### Remediation action:

1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).
2. Click on **Devices** and then under **Managed devices** on **Compliance**.
3. Click **Compliance settings**.
4. Ensure **Mark devices with no compliance policy assigned as** set to **Not compliant**

##### PowerShell

1. Connect to Microsoft Graph using `Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"`
2. Run the following commands:
```powershell
$Uri = 'https://graph.microsoft.com/v1.0/deviceManagement'
$Body = @{
    settings = @{
        secureByDefault = $true
    }
} | ConvertTo-Json
Invoke-MgGraphRequest -Uri $Uri -Method PATCH -Body $Body
```

#### Related links

* [Microsoft Intune admin center](https://intune.microsoft.com)
* [Use compliance policies to set rules for devices you manage with Intune](https://learn.microsoft.com/en-us/intune/intune-service/protect/device-compliance-get-started)
* [CIS Microsoft 365 Foundations Benchmark v6.0.1 - Page 162](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%