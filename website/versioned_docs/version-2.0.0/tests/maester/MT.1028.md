---
title: MT.1028 - No user with mailbox and permanent role assignment on Control Plane
description: Checks if privileged user with assignment to high-privileged roles is mail-enabled
slug: /tests/MT.1028
sidebar_class_name: hidden
---

# No user with mailbox and permanent role assignment on Control Plane

## Description

Permanent Assignments of high-privileged Entra ID directory roles will be checked to identify privileges for users with enabled mailboxes. Related roles will be identified based on the classification model from the [EntraOps](https://github.com/Cloud-Architekt/AzurePrivilegedIAM) project which helps to identify directory roles with Control Plane (Tier0) permissions.

## How to fix

Take attention on mail-enabled administrative accounts with Control Plane privileges.
It's recommended to use mail forwarding to regular work account which allows to avoid direct mail access and phishing attacks on privileged user.

## Learn more

  - [Securing privileged access for hybrid and cloud deployments in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-planning#ensure-separate-user-accounts-and-mail-forwarding-for-global-administrator-accounts)

