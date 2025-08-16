---
title: MT.1071 - App registrations with privileged API permissions should have no owners
description: Checks if app registrations with Control-/Management Plane or high critical API permissions have ownership assigned
slug: /tests/MT.102
sidebar_class_name: hidden
---

# No external user with permanent role assignment on Control Plane

## Description

Ownership on app registrations with high-privileged or sensitive API permissions should not be assigned.

High privileged app registration will be identified by using data from OAuthAppInfo from Microsoft Defender XDR including enrichment by high privilege level status from MDA App Governance but also Control Plane and Management Plane classification by the community project [EntraOps](https://github.com/Cloud-Architekt/AzurePrivilegedIAM). Ownership on app registrations will be identified by Microsoft Security Exposure Management. The flag `Tier breach` will be set based on the classification of the owner (identified by assignment of directory roles) in comparision to the classification of the service principal.

## How to fix
Remove the ownership and replace it (if necessary) by using [object-level role assignments](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/manage-roles-portal?tabs=admin-center#assign-roles-with-app-registration-scope) and avoid any lateral movement paths by delegation to administrator with lower privilege classification (tier breach.)

## Learn more
  - [Securing privileged access for hybrid and cloud deployments in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-planning#ensure-separate-user-accounts-and-mail-forwarding-for-global-administrator-accounts)
