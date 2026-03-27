---
title: MT.1118 - Ensure that SharePoint guest users cannot share items they don't own
description: Ensure that SharePoint guest users cannot share items they don't own
slug: /tests/MT.1118
sidebar_class_name: hidden
---

## Description
7.2.5 (L2) Ensure that SharePoint guest users cannot share items they don't own

Description:
SharePoint gives users the ability to share files, folders, and site collections. Internal users can share with external collaborators, and with the right permissions could share to other external parties.

Rationale:
Sharing and collaboration are key; however, file, folder, or site collection owners should have the authority over what external users get shared with to prevent unauthorized disclosures of information.

Impact:
The impact associated with this change is highly dependent upon current practices. If users do not regularly share with external parties, then minimal impact is likely.
However, if users do regularly share with guests/externally, minimum impacts could occur as those external users will be unable to 're-share' content.

## Related Links

* [Manage sharing settings for SharePoint and OneDrive in Microsoft 365 | Microsoft Learn](https://learn.microsoft.com/en-us/sharepoint/turn-external-sharing-on-or-off#change-the-organization-level-external-sharing-setting)
* CIS 7.2.5 (L2) Ensure that SharePoint guest users cannot share items they don't own