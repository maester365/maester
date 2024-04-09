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
The Conditional Access What If API is currently in public preview and is subject to change.
Maester tests written using this API may need to be updated as the API moves towards General Availability.

Please make sure you have the latest version of Maester installed.
:::

## Writing Conditional Access What-If tests

The Maester PowerShell module includes the **Test-MtConditionalAccessWhatIf** cmdlet that allows you to run What-If tests against your Conditional Access policies.

## Usage

```powershell
Test-MtConditionalAccessWhatIf -UserId 7a6da1c3-616a-416b-a820-cbe4fa8e225e -IncludeApplications "00000002-0000-0ff1-ce00-000000000000" -ClientAppType exchangeActiveSync
```

This request will return all conditional access policies that are in scope when user **7a6da1c3-616a-416b-a820-cbe4fa8e225e** signs into  **Office 365 Exchange Online** using a **Exchange Active Sync** client.

<!-- ![Conditional Access Policies returned by Test-MtConditionalAccessWhatIf](assets/Test-MtConditionalAccessWhatIf.png) -->
