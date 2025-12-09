---
title: MT.1078 - App registrations with highly privileged directory roles should not have owners
description: Checks if service principals with Control/Management Plane or other privileged directory roles have ownership assigned on the application object
slug: /tests/MT.1078
sidebar_class_name: hidden
---

# App registrations with highly privileged directory roles should not have owners

## Prerequisites
Assignments to Microsoft Entra will be analyzed by using the `IdentityInfo` in Microsoft Defender XDR.
As documented in [Microsoft Learn](https://learn.microsoft.com/en-us/defender-xdr/advanced-hunting-identityinfo-table), the details of `PrivilegedEntraPimRoles` are only available for tenants with Microsoft Defender for Identity.
Therefore, the checks are only available for tenants with onboarded MDI instance.

In addition, the table `OAuthAppInfo` will be used to get details about applications including unused permissions and permission scope / criticiality. This table is populated by app governance records from Microsoft Defender for Cloud Apps.
You need to turn on app governance to use this check. To turn on app governance, follow the steps in [Turn on app governance](https://learn.microsoft.com/en-us/defender-cloud-apps/app-governance-get-started).

## Description

Ownership of app registrations with Control/Management roles (classified by EntraOps) or flagged as privileged roles by Entra ID role definition should not be assigned.

Permanent or eligible assignments on Entra roles will be collected from `IdentityInfo` in Microsoft Defender XDR, including enrichment by the `IsPrivileged` flag from the Entra ID role definition, as well as Control Plane and Management Plane classification by the community project [EntraOps](https://github.com/Cloud-Architekt/AzurePrivilegedIAM). Ownership of app registrations is identified by Microsoft Security Exposure Management. The flag `Tier breach` is set based on the classification of the owner (identified by assignment of directory roles) in comparison to the classification of the service principal.

_Side Note: Currently, due to limitations of XSPM data, only assignments on application objects are identified._

Especially, owners with lower privilege than the application should be removed from ownership.
Microsoft also mentions this [risk of elevation of privilege](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/overview-assign-app-owners) over what the owner has access to as a user.
Those delegations can be identified by the `Tier breach` flag in the test results.

But even owners with the same or higher privilege should not be delegated ownership because of missing support for just-in-time access (eligibility in PIM), enforced step-up authentication (authentication context by PIM in Entra ID roles), or assignment via group membership.

## How to fix
Remove ownership and replace it (if necessary) by using [object-level role assignments](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/manage-roles-portal?tabs=admin-center#assign-roles-with-app-registration-scope), and avoid any lateral movement paths by delegating to administrators with lower privilege classification (tier breach).