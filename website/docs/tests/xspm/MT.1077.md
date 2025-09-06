---
title: MT.1077 - App registrations with privileged API permissions should have no owners
description: Checks if app registrations with Control/Management Plane or highly critical API permissions have ownership assigned
slug: /tests/MT.1077
sidebar_class_name: hidden
---

# App registrations with privileged API permissions should not have owners

## Description

Ownership of app registrations with high-privileged or sensitive API permissions should not be assigned.

High-privileged app registrations are identified using data from `OAuthAppInfo` in Microsoft Defender XDR, including enrichment by high privilege level status from MDA App Governance, as well as Control Plane and Management Plane classification by the community project [EntraOps](https://github.com/Cloud-Architekt/AzurePrivilegedIAM). Ownership of app registrations is identified by Microsoft Security Exposure Management. The flag `Tier breach` is set based on the classification of the owner (identified by assignment of directory roles) in comparison to the classification of the service principal.

_Side Note: Currently, due to limitations of XSPM data, only assignments on application objects are identified._

Especially, owners with lower privilege than the application should be removed from ownership.
Microsoft also mentions this [risk of elevation of privilege](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/overview-assign-app-owners) over what the owner has access to as a user.
Those delegations can be identified by the `Tier breach` flag in the test results.

But even owners with the same or higher privilege should not be delegated ownership because of missing support for just-in-time access (eligibility in PIM), enforced step-up authentication (authentication context by PIM in Entra ID roles), or assignment via group membership.

## How to fix
Remove ownership and replace it (if necessary) by using [object-level role assignments](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/manage-roles-portal?tabs=admin-center#assign-roles-with-app-registration-scope), and avoid any lateral movement paths by delegating to administrators with lower privilege classification (tier breach).