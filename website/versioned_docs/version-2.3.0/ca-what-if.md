---
title: Conditional Access What-If tests
---

## Overview

The [**Conditional Access What If policy tool**](https://learn.microsoft.com/entra/identity/conditional-access/what-if-tool) in the Microsoft Entra Portal allows you to understand the result of Conditional Access policies in your environment. Instead of test driving your policies by performing multiple sign-ins manually, this tool enables you to evaluate a simulated sign-in of a user. The simulation estimates the result this sign-in has on your policies and generates a report.

The What If policy tool now is now supported in Microsoft Graph API allowing sign-in simulations to be run programmatically.

## Conditional access regression testing with Maester

The Maester framework allows you to define tests that can be run against your Conditional Access policies using the What If API. The tests can be run as part of your daily automation tests and when you make changes to your policies.

This way you can ensure that your security policies are correctly configured and that they do not break when changes are made to your environment.

 :::info Important
The Conditional Access What If API is currently in beta and is subject to change.
Maester tests written using this API may need to be updated as the API moves towards v1.0.

Please make sure you have the latest version of Maester installed.
:::

## Writing Conditional Access What-If tests

The Maester PowerShell module includes the **Test-MtConditionalAccessWhatIf** cmdlet that allows you to run What-If tests against your Conditional Access policies.

Here is a sample test that uses the **Test-MtConditionalAccessWhatIf** cmdlet to test a user sign-in against a Conditional Access policy.
The sign in is simulated for a user **john@contoso.com** who is signing into **Office 365** from **France** from a specific **IP address** using a **browser** on a **Windows** device.

The test will return all Conditional Access policies that are in scope for the user sign-in.

```powershell
$userId = (Get-MgUser -UserId 'john@contoso.com').Id
$sharePointAppId = '67ad5377-2d78-4ac2-a867-6300cda00e85'

Test-MtConditionalAccessWhatIf -UserId $userId `
    -IncludeApplications $sharePointAppId `
    -Country FR -IpAddress '92.205.185.202' `
    -SignInRiskLevel High `
    -UserRiskLevel Low `
    -ClientAppType browser `
    -DevicePlatform Windows
```

A Maester test can be written to simulate a user sign in and check if a specific Conditional Access policy is enforced.

### Example 1: Test if MFA is enforced for Office 365 sign-in

In the following example, the test checks if the Conditional Access policy enforces MFA for the user sign-in to Office 365.

- The test queries the What If API to simulate the sign-in for the user John accessing SharePoint.
- Running **Test-MtConditionalAccessWhatIf** with this test scenario returns the list of Conditional Access policies that would have been enforced for this scenario.
- The last line of the test checks if there are any policies that contain MFA as a grant control, indicating that MFA is enforced for the user sign-in.

```powershell
Describe "Contoso.ConditionalAccess" {
    It "Microsoft 365 access requires MFA" {

        $userId = (Get-MgUser -UserId 'john@contoso.com').Id
        $sharePointAppId = '67ad5377-2d78-4ac2-a867-6300cda00e85'

        $policiesEnforced = Test-MtConditionalAccessWhatIf -UserId $userId -IncludeApplications $sharePointAppId

        $policiesEnforced.grantControls.builtInControls | Should -Contain "mfa"
    }
}
```

### Example 2: Test if non-Admin users are blocked from accessing the Azure portal

- This test queries the What If API to simulate the sign-in for the user Adele accessing the Azure Portal.
- Running **Test-MtConditionalAccessWhatIf** should return at least one Conditional Access policy that blocks access to the Azure portal for Adele, an unprivileged user.

```powershell
Describe "Contoso.ConditionalAccess" {
    It "Block access to the Azure portal for non-admin users" {

        $userId = (Get-MgUser -UserId 'adele@contoso.com').Id
        $azureAppId = 'c44b4083-3bb0-49c1-b47d-974e53cbdf3c'

        $policiesEnforced = Test-MtConditionalAccessWhatIf -UserId $userId -IncludeApplications $azureAppId

        $policiesEnforced.grantControls.builtInControls | Should -Contain "block"
    }
}
```

## Next steps

- To learn more about the **Test-MtConditionalAccessWhatIf** cmdlet, including the supported parameters and examples see [Test-MtConditionalAccessWhatIf | Maester Reference](https://maester.dev/docs/commands/Test-MtConditionalAccessWhatIf).
- For a step by step guide on writing custom Maester tests and running them see [Writing Maester tests](/docs/writing-tests).
