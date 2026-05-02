---
title: MT.1025 - No external user with permanent role assignment on Control Plane
description: Checks if external user have no high-privileged roles
slug: /tests/MT.1025
sidebar_class_name: hidden
---

# No external user with permanent role assignment on Control Plane

## Description

Permanent Assignments of high-privileged Entra ID directory roles will be checked to identify privileges for external users. Related roles will be identified based on the classification model from the [EntraOps](https://github.com/Cloud-Architekt/AzurePrivilegedIAM) project which helps to identify directory roles with Control Plane (Tier0) permissions.

## How to fix

Verify the affected external users, the user source (e.g., MSSP/partner or managing tenant) and if the privileged accounts pass your requirements for Conditional Access, Lifecycle Workflow and Identity Protection.

## Learn more
  - [Securing privileged access for hybrid and cloud deployments in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-planning#ensure-separate-user-accounts-and-mail-forwarding-for-global-administrator-accounts)
