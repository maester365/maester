---
title: MT.1081 - Hybrid users should not be assigned Entra ID role assignments
description: Checks for eligible or permanent Entra ID roles that have been assigned to hybrid users.
slug: /tests/MT.1081
sidebar_class_name: hidden
---

# Hybrid users should not be assigned Entra ID role assignments

## Prerequisites
Assignments to Microsoft Entra will be analyzed by using the `IdentityInfo` in Microsoft Defender XDR.
As documented in [Microsoft Learn](https://learn.microsoft.com/en-us/defender-xdr/advanced-hunting-identityinfo-table), the details of `PrivilegedEntraPimRoles` are only available for tenants with Microsoft Defender for Identity.
Therefore, the checks are only available for tenants with onboarded MDI instance.

In addition, the table `OAuthAppInfo` will be used to get details about applications including unused permissions and permission scope / criticiality. This table is populated by app governance records from Microsoft Defender for Cloud Apps.
You need to turn on app governance to use this check. To turn on app governance, follow the steps in [Turn on app governance](https://learn.microsoft.com/en-us/defender-cloud-apps/app-governance-get-started).

## Description

Permanent or eligible assignments on Entra roles will be collected from `IdentityInfo` in Microsoft Defender XDR, including enrichment by the `IsPrivileged` flag from the Entra ID role definition, as well as Control Plane and Management Plane classification by the community project [EntraOps](https://github.com/Cloud-Architekt/AzurePrivilegedIAM). In addition, `SourceProvider` from this table will be used to identify if the user has been provisioned by Active Directory.

Microsoft strongly recommends avoiding the use of synchronized identities to manage Microsoft 365 or Microsoft Entra environments for [protecting against on-premises attacks](https://learn.microsoft.com/en-us/entra/architecture/protect-m365-from-on-premises-attacks).

## How to fix
Create [dedicated privileged users](https://learn.microsoft.com/en-us/microsoft-365/enterprise/protect-your-global-administrator-accounts?view=o365-worldwide) to assign and use Entra ID roles, and remove the previous role assignments for the on-premises accounts.