---
title: MT.1077 - App registrations with privileged API permissions should have no owners
description: Checks if app registrations with Control/Management Plane or highly critical API permissions have ownership assigned
slug: /tests/MT.1077
sidebar_class_name: hidden
---

# App registrations with privileged API permissions should not have owners

## Prerequisites
Assignments to Microsoft Entra will be analyzed by using the `IdentityInfo` in Microsoft Defender XDR.
As documented in [Microsoft Learn](https://learn.microsoft.com/en-us/defender-xdr/advanced-hunting-identityinfo-table), the details of `PrivilegedEntraPimRoles` are only available for tenants with Microsoft Defender for Identity.
Therefore, the checks are only available for tenants with onboarded MDI instance.

In addition, the table `OAuthAppInfo` will be used to get details about applications including unused permissions and permission scope / criticiality. This table is populated by app governance records from Microsoft Defender for Cloud Apps.
You need to turn on app governance to use this check. To turn on app governance, follow the steps in [Turn on app governance](https://learn.microsoft.com/en-us/defender-cloud-apps/app-governance-get-started).

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