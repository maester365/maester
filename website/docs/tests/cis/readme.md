---
id: overview
title: CIS Microsoft 365 Foundations Benchmark Tests
sidebar_label: 🏢 CIS Overview
description: Implementation of CIS Microsoft 365 Foundations Benchmark Controls
---

# CIS Microsoft 365 Foundations Benchmark

## Overview

The tests in this section verifies that a Micorosft 365 tenant's configuration conforms to the [CIS Microsoft 365 Foundations Benchmark](https://www.cisecurity.org/benchmark/microsoft_365) recommendations (v3.1.0).

The CIS published material is shared for these tests as it aligns with their licensing of [CC BY-NC-SA 4.0](https://www.cisecurity.org/terms-and-conditions-table-of-contents).

## Connecting to Azure, Exchange and other services

In order to run all the CIS tests, you need to install and connect to the Azure and Exchange Online modules.

See the [Installation guide](/docs/installation#optional-modules-and-permissions) for more information.

## Tests

It is important to note that a number of the policy checks ONLY check the default policy, and not every policy. CIS 2.1.7 `Test-MtCisSafeAntiPhishingPolicy` is one example.

| Cmdlet Name | CIS Recommendation ID |
| - | - |
| Test-MtCisCloudAdmin | 1.1.1 (L1) Ensure Administrative accounts are separate and cloud-only |
| TBD | 1.1.2 (L1) Ensure two emergency access accounts have been defined |
| Test-MtCisGlobalAdminCount | 1.1.3 (L1) Ensure that between two and four global admins are designated |
| N/A | 1.1.4 (L1) Ensure Guest Users are reviewed at least biweekly |
| Test-MtCis365PublicGroup | 1.2.1 (L2) Ensure that only organizationally managed/approved public groups exist |
| Test-MtCisSharedMailboxSignIn | 1.2.2 (L1) Ensure sign-in to shared mailboxes is blocked |
| Test-MtCisPasswordExpiry | 1.3.1 (L1) Ensure the 'Password expiration policy' is set to 'Set passwords to never expire (recommended)' |
| TBD | 1.3.2 (L1) Ensure 'Idle session timeout' is set to '3 hours (or less)' for unmanaged devices |
| Test-MtCisCalendarSharing | 1.3.3 (L2) Ensure 'External sharing' of calendars is not available |
| TBD | 1.3.4 (L1) Ensure 'User owned apps and services' is restricted |
| TBD | 1.3.5 (L1) Ensure internal phishing protection for Forms is enabled |
| Test-MtCisCustomerLockBox | 1.3.6 (L2) Ensure the customer lockbox feature is enabled |
| TBD | 1.3.7 (L2) Ensure 'third-party storage services' are restricted in 'Microsoft 365 on the web' |
| TBD | 1.3.8 (L2) Ensure that Sways cannot be shared with people outside of your organization |
| Test-MtCisSafeLink | 2.1.1 (L2) Ensure Safe Links for Office Applications is Enabled |
| Test-MtCisAttachmentFilter | 2.1.2 (L1) Ensure the Common Attachment Types Filter is enabled |
| Test-MtCisInternalMalwareNotification | 2.1.3 (L1) Ensure notifications for internal users sending malware is Enabled |
| Test-MtCisSafeAttachment | 2.1.4 (L2) Ensure Safe Attachments policy is enabled |
| Test-MtCisSafeAttachmentsAtpPolicy | 2.1.5 (L2) Ensure Safe Attachments for SharePoint, OneDrive, and Microsoft Teams is Enabled |
| Test-MtCisOutboundSpamFilterPolicy | 2.1.6 (L1) Ensure Exchange Online Spam Policies are set to notify administrators |

TBD in this case refers to CIS "manual" checks. It might be possible to automate these, but skipping for now to focus on automated checks.