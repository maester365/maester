---
title: MT.1079 - Privileged API permissions on service principals should not remain unused
description: Checks for unused API permissions (detected by MDA App Governance) that have also been identified with classification as Control/Management Plane or highly critical API permissions
slug: /tests/MT.1079
sidebar_class_name: hidden
---

# Privileged API permissions on service principals should not remain unused

## Description

The status of used API permissions for a service principal is analyzed by App Governance in Microsoft Defender for Cloud Apps and is available in `OAuthAppInfo`.
Identified unused app role assignments are correlated with the definition of `PrivilegeLevel` from App Governance and classification by the community project [EntraOps](https://github.com/Cloud-Architekt/AzurePrivilegedIAM). Only affected API permissions related to the privilege level "high" or Control/Management Plane classification will be shown in the report.


Here is your text with corrected grammar and spelling:

Especially, owners with lower privilege than the application should be removed from ownership.
Microsoft also mentions this risk of elevation of privilege over what the owner has access to as a user.
Even owners with the same or higher privilege should not be delegated ownership because of missing support for just-in-time access (eligibility in PIM), enforced step-up authentication (authentication context by PIM in Entra ID roles), or assignment via group membership.

Unused privileged permissions should not remain assigned to a service principal because they increase the attack surface and risk of unauthorized access. If these permissions are not required for the application's functionality, they can be exploited by attackers or misused, leading to potential privilege escalation or data exposure. Removing unnecessary privileged permissions helps maintain a stronger security posture and reduces the likelihood of security incidents.

## How to fix
Review the findings in the [Applications inventory](https://learn.microsoft.com/en-us/defender-cloud-apps/applications-inventory#oauth-apps) in App Governance, and verify that there are no activities or use cases requiring the affected service principal to have assignments to these API permissions. Use [hunting of app activities](https://learn.microsoft.com/en-us/defender-cloud-apps/app-activity-threat-hunting) to review access and required permissions.