---
title: MT.1117 - Ensure guest access to a site or OneDrive will expire automatically
description: Ensure guest access to a site or OneDrive will expire automatically
slug: /tests/MT.1117
sidebar_class_name: hidden
---

## Description
7.2.9 (L1) Ensure guest access to a site or OneDrive will expire automatically

Description:
This policy setting configures the expiration time for each guest that is invited to the SharePoint site or with whom users share individual files and folders with.
The recommended state is 30 or less.

Rationale:
This setting ensures that guests who no longer need access to the site or link no longer have access after a set period of time. Allowing guest access for an indefinite amount of time could lead to loss of data confidentiality and oversight.
Note: Guest membership applies at the Microsoft 365 group level. Guests who have permission to view a SharePoint site or use a sharing link may also have access to a Microsoft Teams team or security group.

Impact:
Site collection administrators will have to renew access to guests who still need access after 30 days. They will receive an e-mail notification once per week about guest access that is about to expire.
**Note:** The guest expiration policy only applies to guests who use sharing links or guests who have direct permissions to a SharePoint site after the guest policy is enabled. The guest policy does not apply to guest users that have pre-existing permissions or access through a sharing link before the guest expiration policy is applied

## Related Links

* [Manage sharing settings for SharePoint and OneDrive in Microsoft 365 | Microsoft Learn](https://learn.microsoft.com/en-us/sharepoint/turn-external-sharing-on-or-off#change-the-organization-level-external-sharing-setting)
* CIS 7.2.9 (L1) Ensure guest access to a site or OneDrive will expire automatically