---
title: MT.1081 - Hybrid users should not be assigned Entra ID role assignments
description: Checks for eligible or permanent Entra ID roles that have been assigned to hybrid users.
slug: /tests/MT.1081
sidebar_class_name: hidden
---

# Hybrid users should not be assigned Entra ID role assignments

## Description

Permanent or eligible assignments on Entra roles will be collected from `IdentityInfo` in Microsoft Defender XDR, including enrichment by the `IsPrivileged` flag from the Entra ID role definition, as well as Control Plane and Management Plane classification by the community project [EntraOps](https://github.com/Cloud-Architekt/AzurePrivilegedIAM). In addition, `SourceProvider` from this table will be used to identify if the user has been provisioned by Active Directory.

Microsoft strongly recommends avoiding the use of synchronized identities to manage Microsoft 365 or Microsoft Entra environments for [protecting against on-premises attacks](https://learn.microsoft.com/en-us/entra/architecture/protect-m365-from-on-premises-attacks).

## How to fix
Create [dedicated privileged users](https://learn.microsoft.com/en-us/microsoft-365/enterprise/protect-your-global-administrator-accounts?view=o365-worldwide) to assign and use Entra ID roles, and remove the previous role assignments for the on-premises accounts.