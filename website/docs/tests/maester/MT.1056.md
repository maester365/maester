---
title: MT.1056 - User Access Administrator permission should not be permanently assigned on the root scope
description: Global Admins should not have permanent access to Azure Subscriptions at the root scope
slug: /tests/MT.1056
sidebar_class_name: hidden
---

# User Access Administrator permission should not be permanently assigned on the root scope

## Description
Ensure that no person has permanent access to Azure Subscriptions.

User Access Administrator is a role that allows an Administrator to perform everything on an Azure Subscription. Global Administrators can gain this permission on the Root Scope in Entra ID, in the properties of Entra ID. These permissions should only be used in case of emergency and should not be assigned permanently.

Ensure that no User Access Administrator permissions at the Root Scope are applied.

## How to fix

To remove all Admins with Root Scope permissions, as a Global Admin:
1. Navigate to [Microsoft Entra admin center](https://entra.microsoft.com).
2. Navigate to **Entra ID** > **Overview**.
3. Click on **Properties**.
3. On the **Properties** page, go to the **Access management for Azure resources** section.
4. Eleveate your account by toggle the switch to **Yes** and refresh the page.
5. In the yellow information bar, click: **Manage elevated access users**.
6. Select all User Access Administrators, and click **Remove**.
7. Remove elevated access your account by setting the toggle to **No**.

To remove the admins through CLI:
```powershell
az role assignment delete --role "User Access Administrator" --assignee adminname@yourdomain.com --scope "/"
```

## Learn more

* [Elevate access to manage all Azure subscriptions and management groups](https://learn.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin)

