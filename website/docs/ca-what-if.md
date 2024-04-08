---
title: Conditional Access What-If Tests
---

The Conditional Access What-If cmdlet **Test-MtConditionalAccessWhatIf** is tailored to easily query the Microsoft Graph API 'conditionalAccess/evaluate' endpoint.

:::info Important
This endpoint is currently in public preview and might change.
Please make sure you have the latest version of maester installed.
:::

## Usage

```powershell
Test-MtConditionalAccessWhatIf -UserId 7a6da1c3-616a-416b-a820-cbe4fa8e225e -IncludeApplications "00000002-0000-0ff1-ce00-000000000000" -ClientAppType exchangeActiveSync
```

This request will return all conditional access policies that are in scope when user **7a6da1c3-616a-416b-a820-cbe4fa8e225e** signs into  **Office 365 Exchange Online** using a **Exchange Active Sync** client.

![Conditional Access Policies returned by Test-MtConditionalAccessWhatIf](assets/Test-MtConditionalAccessWhatIf.png)
