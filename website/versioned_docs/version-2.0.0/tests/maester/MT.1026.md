---
title: MT.1026 - No hybrid user with permanent role assignment on Control Plane
description: Checks if External user have no high-privileged roles
slug: /tests/MT.1026
sidebar_class_name: hidden
---

# No hybrid user with permanent role assignment on Control Plane

## Description

Permanent Assignments of high-privileged Entra ID directory roles will be checked to identify privileges for hybrid users. Related roles will be identified based on the classification model from the [EntraOps](https://github.com/Cloud-Architekt/AzurePrivilegedIAM) project which helps to identify directory roles with Control Plane (Tier0) permissions.

## How to fix

It's recommended to use cloud-only accounts for privileges with Control Plane privileges to avoid attack paths from on-premises environment.

## Learn more

  - [Securing privileged access for hybrid and cloud deployments in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-planning#ensure-separate-user-accounts-and-mail-forwarding-for-global-administrator-accounts)
  - [Protecting Microsoft 365 from on-premises attacks](https://learn.microsoft.com/en-us/entra/architecture/protect-m365-from-on-premises-attacks#isolate-privileged-identities)
