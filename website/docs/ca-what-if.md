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

A Maester test can simulate a sign-in and check that the expected Conditional Access policy applies. Each example
below is a [native test](/docs/writing-tests): save the function as `Test.<ID>.ps1` in your `custom` folder, with a
`Test.<ID>.md` file beside it that describes the test, then run it with `Invoke-MtTest -Path` or `Invoke-Maester`.

### Example 1: Test if MFA is enforced for Office 365 sign-in

The test checks that a Conditional Access policy requires MFA when John signs in to Office 365.

- It simulates John's sign-in to SharePoint with the What If API.
- **Test-MtConditionalAccessWhatIf** returns the Conditional Access policies that would apply to that sign-in.
- The test passes when one of those policies has MFA as a grant control.

`custom/Test.CONTOSO.2001.ps1`:

```powershell
function Test-ContosoM365AccessRequiresMfa {
    [MaesterTest(
        Id       = 'CONTOSO.2001',
        Title    = 'Microsoft 365 access requires MFA.',
        Severity = 'High',
        Category = 'Contoso/Conditional Access',
        Tag      = ('CA', 'Contoso'),
        Service  = 'Graph',
        CompatibleLicense = 'AAD_PREMIUM'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The user whose sign-in is simulated.
        [string] $UserPrincipalName = 'john@contoso.com'
    )

    $userId = (Invoke-MtGraphRequest -RelativeUri "users/$UserPrincipalName").id
    $sharePointAppId = '67ad5377-2d78-4ac2-a867-6300cda00e85'

    $policiesEnforced = Test-MtConditionalAccessWhatIf -UserId $userId -IncludeApplications $sharePointAppId
    $requiresMfa = $policiesEnforced.grantControls.builtInControls -contains 'mfa'

    if ($requiresMfa) {
        Add-MtTestResultDetail -Result "Well done. A Conditional Access policy requires MFA when $UserPrincipalName signs in to Microsoft 365."
    } else {
        Add-MtTestResultDetail -Result "No Conditional Access policy requires MFA when $UserPrincipalName signs in to Microsoft 365."
    }
    return $requiresMfa
}
```

### Example 2: Test if non-Admin users are blocked from accessing the Azure portal

- The test simulates a sign-in to the Azure portal by Adele, a user with no admin roles.
- It passes when **Test-MtConditionalAccessWhatIf** returns at least one policy that blocks that sign-in.

`custom/Test.CONTOSO.2002.ps1`:

```powershell
function Test-ContosoAzurePortalBlockedForUsers {
    [MaesterTest(
        Id       = 'CONTOSO.2002',
        Title    = 'Users without admin roles are blocked from the Azure portal.',
        Severity = 'High',
        Category = 'Contoso/Conditional Access',
        Tag      = ('CA', 'Contoso'),
        Service  = 'Graph',
        CompatibleLicense = 'AAD_PREMIUM'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # A user with no admin roles.
        [string] $UserPrincipalName = 'adele@contoso.com'
    )

    $userId = (Invoke-MtGraphRequest -RelativeUri "users/$UserPrincipalName").id
    $azureAppId = 'c44b4083-3bb0-49c1-b47d-974e53cbdf3c'

    $policiesEnforced = Test-MtConditionalAccessWhatIf -UserId $userId -IncludeApplications $azureAppId
    $blocked = $policiesEnforced.grantControls.builtInControls -contains 'block'

    if ($blocked) {
        Add-MtTestResultDetail -Result "Well done. Conditional Access blocks $UserPrincipalName from the Azure portal."
    } else {
        Add-MtTestResultDetail -Result "No Conditional Access policy blocks $UserPrincipalName from the Azure portal."
    }
    return $blocked
}
```

Both tests take the user as a parameter, so you can point them at a real account in your tenant from
`maester-config.json` instead of editing the file. Tests written for Maester 2.x as Pester `Describe` / `It` blocks
still run; see [Pester-format tests](/docs/writing-tests/pester-format-tests) and `Convert-MtTest`.

## Next steps

- To learn more about the **Test-MtConditionalAccessWhatIf** cmdlet, including the supported parameters and examples see [Test-MtConditionalAccessWhatIf | Maester Reference](https://maester.dev/docs/commands/Test-MtConditionalAccessWhatIf).
- For a step by step guide on writing custom Maester tests and running them see [Writing Maester tests](/docs/writing-tests).
