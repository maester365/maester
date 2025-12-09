---
title: MT.1051 - Apps with high-risk permissions having an indirect path to Global Admin
description: Checks if any application has tier-0 graph permissions with a risk of having an indirect path to Global Admin and full tenant takeover.
slug: /docs/tests/MT.1051
sidebar_class_name: hidden
---

# Apps with high-risk permissions having an indirect path to Global Admin

## Description

This test checks if any application has tier-0 graph permissions with a risk of having an indirect path to Global Admin and full tenant takeover.

Note:\
There are several use cases where Tier-0 permissions with an indirect attack path are required. For example, Maester itself requires the permission 'RoleEligibilitySchedule.ReadWrite.Directory' to properly validate the PIM assignments. Nevertheless, an administrator should question the use of these permissions and check whether less critical permissions are also sufficient. Applications that are provided by third-party vendors that do have Tier-0 permissions with direct or indirect attack paths should strictly be questioned and monitored.

## How to fix

To check the applications permissions:
1. Navigate to [Microsoft Entra admin center](https://entra.microsoft.com/).
2. Expand **Identity** > **Applications**.
3. Select **All applications**.
4. Search for the application that you want to check and select the application.
5. Select **API permissions**.
6. Check the **Microsoft Graph** permissions.
7. Verify that **only authorized users** have access to this application and its secrets.

## Learn more

* [Emilien Socchi | Application permissions - Tier 0: Family of Global Admins](https://github.com/emiliensocchi/azure-tiering/tree/main/Microsoft%20Graph%20application%20permissions#tier-0)
* [Microsoft Learn | Graph permissions](https://learn.microsoft.com/en-us/graph/permissions-reference)