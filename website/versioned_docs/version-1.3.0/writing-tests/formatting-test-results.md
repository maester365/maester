---
title: Formatting test results
sidebar_position: 2
---

## Overview

In this section we will learn how to format test results to provide more context and make them easier to understand for the person viewing the results.

Let's write a test to check if conditional access policies are following the company's standards.

## A custom Maester test to check conditional access policies standards

Our organization has a policy that all disabled conditional access policies should include the reason for the policy being disabled. This is done by adding a note to the display name in the format `Disabled: <reason>`.

To check if the conditional access policies are following this standard, we can write the following custom test and add it to the `ContosoEntra.Tests.ps1` file in the `Custom` folder (see previous article).

You can copy and paste the following code and add it to the end of the `ContosoEntra.Tests.ps1` file.

```powershell
Describe "ContosoEntraConfig" -Tag "CA", "Contoso" {
   It "Disabled CA policies must have reason for being disabled" {

       try {
          $policies = Get-MgIdentityConditionalAccessPolicy -All
          $disabledWithoutReason = $policies | Where-Object { $_.State -eq "Disabled" -and $_.DisplayName -notlike "*Disabled:*" }
       } catch {
           Write-Error $_.Exception.Message
       }
       $disabledWithoutReason | Should -Be 0
    }
}
```

You can run the test using `Invoke-Maester` and check the results.

What you will notice is that the test results are not very informative. The test will pass or fail, but you won't know which conditional access policies are not following the standard.

![Test results without formatting](img/unformatted-test-result.png)

## Formatting the test results with Add-MtTestResultDetail

### Basic formatting

To provide more context in the test results, you can use Maester's `Add-MtTestResultDetail` function to provide additional context.

![Test results with basic formatting](img/formatted-test-basic.png)

By providing the `-Description` and `-Result` parameters the test results are now more informative and provide context on what the test is checking and the outcome.

Here's the code for the complete custom test.

Copy and paste this code to any `*.Tests.ps1` file in the `Custom` folder to try it out.

```powershell
Describe "ContosoEntraConfig" -Tag "Privilege", "Contoso" {
    It "Disabled CA policies must have reason for being disabled" {

        try {
            $policies = Get-MgIdentityConditionalAccessPolicy -All

            $disabledWithoutReason = $policies | Where-Object { $_.State -eq "Disabled" -and $_.DisplayName -notlike "*Disabled:*" }

            $testDescription = "Checks if the disabled policies have the reason for being disabled."
            if ($disabledWithoutReason.Count -gt 0) {
                $result = "There are $($disabledWithoutReason.Count) disabled policies without a reason for being disabled."
                Add-MtTestResultDetail -Description $testDescription -Result $result
            } else {
                Add-MtTestResultDetail -Description $testDescription -Result "Well done. All disabled policies have a reason for being disabled."
            }
        } catch {
            Write-Error $_.Exception.Message
        }

        $disabledWithoutReason | Should -Be 0
    }
}
```

### Adding graph objects

The test result now shows that 24 policies are failing the test but doesn't provide the names of the policies. To provide more context, you can add the names of the policies that are failing by passing the policies to the `Add-MtTestResultDetail` function.

![Test results showing graph objects](img/formatted-test-graph.png)

The `-GraphObjects` and `-GraphObjectType` parameters in `Add-MtTestResultDetail` allow you to pass objects to the test results and specify the type of object.

The test results can then display the names of the objects and also provide a deep link to the object in the Microsoft admin portal.

:::note
When using `-GraphObjects` the `-Result` string parameter needs to include `%TestResult%` at the position where the object names will be inserted.

The `%TestResult%` placeholder will be replaced with the names of the objects in the test results.
:::

The current list of supported object types includes Users, Groups, Devices, ConditionalAccess, AuthenticationMethod, AuthorizationPolicy, ConsentPolicy, Domains, IdentityProtection and UserRole.

Here's the updated test with the graph objects that you can try out.

```powershell
Describe "ContosoEntraConfig" -Tag "Privilege", "Contoso" {
    It "Disabled CA policies must have reason for being disabled" {

        try {
            $policies = Get-MgIdentityConditionalAccessPolicy -All

            $disabledWithoutReason = $policies | Where-Object { $_.State -eq "Disabled" -and $_.DisplayName -notlike "*Disabled:*" }

            $testDescription = "Checks if the disabled policies have the reason for being disabled."
            if ($disabledWithoutReason.Count -gt 0) {
                $result = "There are $($disabledWithoutReason.Count) disabled policies without a reason for being disabled.`n`n%TestResult%"
                Add-MtTestResultDetail -Description $testDescription -Result $result -GraphObjects $disabledWithoutReason -GraphObjectType ConditionalAccess
            } else {
                Add-MtTestResultDetail -Description $testDescription -Result "Well done. All disabled policies have a reason for being disabled."
            }
        } catch {
            Write-Error $_.Exception.Message
        }

        $disabledWithoutReason | Should -Be 0
    }
}
```

To add support for additional types see [Add-MtTestResultDetail](https://github.com/maester365/maester/blob/main/powershell/public/Add-MtTestResultDetail.ps1) and [Get-GraphObjectMarkdown](https://github.com/maester365/maester/blob/main/powershell/internal/Get-GraphObjectMarkdown.ps1).

#### Adding custom markdown

While the `-GraphObjects` parameter provides an easy option to link to common objects, you can also provide custom markdown to the `-Result` parameter. This allows you to format the test results in any way you like.

Here's an example of how you can use a markdown table to display the results including deep links to the policies in the Microsoft Entra portal.

![Test results with custom markdown](img/formatted-test-custom-markdown.png)

```powershell
Describe "ContosoEntraConfig" -Tag "Privilege", "Contoso" {
    It "Disabled CA policies must have reason for being disabled" {

        try {
            $policies = Get-MgIdentityConditionalAccessPolicy -All

            $disabledWithoutReason = $policies | Where-Object { $_.State -eq "Disabled" -and $_.DisplayName -notlike "*Disabled:*" }
            $disabledWithReason = $policies | Where-Object { $_.State -eq "Disabled" -and $_.DisplayName -like "*Disabled:*" }

            $testDescription = "Checks if the disabled policies have the reason for being disabled."

            if ($disabledWithoutReason.Count -gt 0 ) {
                $result = "There are $($disabledWithoutReason.Count) disabled policies without a reason for being disabled."
            } else {
                $result = "Well done. All disabled policies have a reason for being disabled."
            }
            $portalLink = "https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/{0}"
            if($disabledWithReason.Count -gt 0 -or $disabledWithoutReason.Count -gt 0){
                $result += "`n`n"
                $result += "| Disabled CA Policy | Reason for disabling policy |`n"
                $result += "| --- | --- |`n"
                foreach($policy in $disabledWithReason){
                    $nameSplit = $policy.DisplayName -split ":Disabled:"
                    $result += "| ✅ [$($nameSplit[0])]($($portalLink -f $policy.id)) | $($nameSplit[1]) |`n"
                }
                foreach($policy in $disabledWithoutReason){
                    $result += "| ❌ [$($policy.DisplayName)]($($portalLink -f $policy.id)) | No reason provided |`n"
                }
            }
            Add-MtTestResultDetail -Description $testDescription -Result $result
        } catch {
            Write-Error $_.Exception.Message
        }

        $disabledWithoutReason | Should -Be 0
    }
}
```

