// This file contains the test results data
// The sample data will be replaced by the Get-MtHtmlReport when it runs the generation.

export const testResults = {
  "Result": "Failed",
  "FailedCount": 2,
  "PassedCount": 0,
  "SkippedCount": 0,
  "TotalCount": 2,
  "NotRunCount": 0,
  "ErrorCount": 0,
  "ExecutedAt": "2025-05-12T18:33:09.425618+10:00",
  "TotalDuration": "00:00:00",
  "UserDuration": "00:00:00",
  "DiscoveryDuration": "00:00:00",
  "FrameworkDuration": "00:00:00",
  "TenantId": "0817c655-a853-4d8f-9723-3a333b5b9235",
  "TenantName": "Pora Inc.",
  "Account": "merill@elapora.com",
  "CurrentVersion": "0.1.0",
  "LatestVersion": "1.0.0",
  "Tests": [
    {
      "Index": 1,
      "Id": "MT.1053",
      "Title": "Ensure intune device clean-up rule is configured",
      "Name": "MT.1053: Ensure intune device clean-up rule is configured",
      "HelpUrl": "",
      "Severity": "Medium",
      "Tag": [
        "Maester",
        "Intune",
        "MT.1053"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Test-MtManagedDeviceCleanupSettings\n        if ($null -ne $result) {\n            $result | Should -Be $true -Because \"automatic device clean-up rule is configured.\"\n        }\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Intune/Test-MtIntunePlatform.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Maester/Intune",
      "Duration": "00:00:00",
      "ResultDetail": {
        "TestTitle": "MT.1053: Ensure intune device clean-up rule is configured",
        "SkippedReason": null,
        "TestSkipped": "",
        "Service": null,
        "TestDescription": "Ensure device clean-up rule is configured\n\nThis test checks if the device clean-up rule is configured.\n\nSet your Intune device cleanup rules to delete Intune MDM enrolled devices that appear inactive, stale, or unresponsive. Intune applies cleanup rules immediately and continuously so that your device records remain current.\n\n#### Remediation action:\n\nTo enable device clean-up rules:\n1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).\n2. Click **Devices** scroll down to **Organize devices**.\n3. Select **Device clean-up rules**.\n4. Set **Delete devices based on last check-in date** to **Yes**\n5. Set **Delete devices that haven't checked in for this many days** to **30 days or more** depending on your organizational needs.\n6. Click **Save**.\n\n#### Related links\n\n* [Microsoft 365 Admin Center](https://admin.microsoft.com)\n* [Microsoft Intune - Device clean-up rules](https://intune.microsoft.com/?ref=AdminCenter#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/deviceCleanUp)\n\n",
        "Severity": "",
        "TestResult": "\nYour Intune device clean-up rule is not configured."
      }
    },
    {
      "Index": 2,
      "Id": "MT.1054",
      "Title": "Ensure built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'",
      "Name": "MT.1054: Ensure built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'",
      "HelpUrl": "",
      "Severity": "Medium",
      "Tag": [
        "Maester",
        "Intune",
        "MT.1054"
      ],
      "Result": "Failed",
      "ScriptBlock": "\n        $result = Test-MtDeviceComplianceSettings\n        if ($null -ne $result) {\n            $result | Should -Be $true -Because \"built-in device compliance policy marks devices with no policy assigned as 'Not compliant'.\"\n        }\n    ",
      "ScriptBlockFile": "/Users/merill/GitHub/maester/tests/Maester/Intune/Test-MtIntunePlatform.Tests.ps1",
      "ErrorRecord": [],
      "Block": "Maester/Intune",
      "Duration": "00:00:00",
      "ResultDetail": {
        "TestTitle": "MT.1054: Ensure built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'",
        "SkippedReason": null,
        "TestSkipped": "",
        "Service": null,
        "TestDescription": "Ensure the built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'.\n\nSet your Intune built-in Device Compliance Policy to mark devices with no compliance policy assigned as 'Not compliant'.\nThis ensures that new devices that do not have any policies assigned are not compliant per default.\n\n#### Remediation action:\n\nTo change the built-in device compliance policy:\n1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).\n2. Click **Devices** scroll down to **Manage devices**.\n3. Select **Compliance** and Select **Compliance settings**.\n4. Set **Mark devices with no compliance policy assigned as** to **Not compliant**\n5. Click **Save**.\n\n#### Related links\n\n* [Microsoft 365 Admin Center](https://admin.microsoft.com)\n* [Microsoft Intune - Compliance](https://intune.microsoft.com/?ref=AdminCenter#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)\n* [Compliance policy settings](https://learn.microsoft.com/de-de/mem/intune/protect/device-compliance-get-started#compliance-policy-settings)\n\n",
        "Severity": "",
        "TestResult": "\nYour Intune built-in Device Compliance Policy **incorrectly** marks devices with no compliance policy assigned as 'Compliant'."
      }
    }
  ],
  "Blocks": [
    {
      "Name": "Maester/Intune",
      "Result": "Failed",
      "FailedCount": 2,
      "PassedCount": 0,
      "SkippedCount": 0,
      "NotRunCount": 0,
      "TotalCount": 2,
      "Tag": [
        "Maester",
        "Intune"
      ]
    }
  ]
}

export type TestResults = typeof testResults
export type Test = typeof testResults.Tests[0]
export type Block = typeof testResults.Blocks[0]
