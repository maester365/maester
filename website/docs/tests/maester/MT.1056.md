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
1. Navigate to Microsoft 365 admin center [https://portal.microsoft.com](https://portal.microsoft.com).
2. Search for **Microsoft Entra ID** select **Microsoft Entra ID**.
3. Expand the **Manage** menu, select **Properties**
3. On the **Properties** page, go to the **Access management for Azure resources** section.
4. In the information bar, click: **Manage elevated access users**.
5. Select all User Access Administrators, and click **Remove**

To remove the admins through CLI:
```powershell
az role assignment delete --role "User Access Administrator" --assignee adminname@yourdomain.com --scope "/"
```

## Learn more

* [Elevate access to manage all Azure subscriptions and management groups](https://learn.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin)

