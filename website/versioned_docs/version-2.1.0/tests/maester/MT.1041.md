---
title: MT.1041 - Ensure users installing Outlook add-ins is not allowed
description: Checks if users can install and manage add-ins for Outlook in Exchange Online
slug: /tests/MT.1041
sidebar_class_name: hidden
---

# Ensure users installing Outlook add-ins is not allowed

## Description

> Specify the administrators and users who can install and manage add-ins for Outlook in Exchange Online By default, users can install add-ins in their Microsoft Outlook Desktop client, allowing data access within the client application.
> Rationale: Attackers exploit vulnerable or custom add-ins to access user data. Disabling user installed add-ins in Microsoft Outlook reduces this threat surface.

## How to fix

> 1. Navigate to [Exchange Admin Center](https://admin.cloud.microsoft.com/exchange)
> 2. Click to expand **Roles** and select **User roles** in the navigation pane.
> 3. Select **Default Role Assignment Policy**.
> 4. In the properties pane on the right click on **Manage permissions**.
> 5. Under **Other roles** uncheck the following:
> * My Custom Apps
> * My Marketplace Apps
> * My ReadWriteMailboxApps
> 6. Click **Save changes**.
