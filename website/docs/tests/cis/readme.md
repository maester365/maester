---
id: overview
title: CIS Microsoft 365 Foundations Benchmark Tests
sidebar_label: 🌀 CIS
description: Implementation of CIS Microsoft 365 Foundations Benchmark Controls
---

# CIS Microsoft 365 Foundations Benchmark

## Overview

The tests in this section verifies that a Microsoft 365 tenant's configuration conforms to the [CIS Microsoft 365 Foundations Benchmark](https://www.cisecurity.org/benchmark/microsoft_365) recommendations (v3.1.0).

The CIS published material is shared for these tests as it aligns with their licensing of [CC BY-NC-SA 4.0](https://www.cisecurity.org/terms-and-conditions-table-of-contents).

## Connecting to Azure, Exchange and other services

In order to run all the CIS tests, you need to install and connect to the Azure and Exchange Online modules.

See the [Installation guide](/docs/installation#optional-modules-and-permissions) for more information.

## Tests

It is important to note that a number of the policy checks ONLY check the default policy, and not every policy. CIS 2.1.7 `Test-MtCisSafeAntiPhishingPolicy` is one example.

:::info
TBD below refers to CIS "manual" checks. It might be possible to automate these, but skipping for now to focus on automated checks.
N/A below refers to review checks which cannot be automated.
:::

| Cmdlet Name | CIS Recommendation ID |
| - | - |
| [Test-MtCisCloudAdmin](/docs/commands/Test-MtCisCloudAdmin) | 1.1.1 (L1) Ensure Administrative accounts are separate and cloud-only |
| TBD | 1.1.2 (L1) Ensure two emergency access accounts have been defined |
| [Test-MtCisGlobalAdminCount](/docs/commands/) | 1.1.3 (L1) Ensure that between two and four global admins are designated |
| N/A | 1.1.4 (L1) Ensure Guest Users are reviewed at least biweekly |
| [Test-MtCis365PublicGroup](/docs/commands/) | 1.2.1 (L2) Ensure that only organizationally managed/approved public groups exist |
| [Test-MtCisSharedMailboxSignIn](/docs/commands/) | 1.2.2 (L1) Ensure sign-in to shared mailboxes is blocked |
| [Test-MtCisPasswordExpiry](/docs/commands/) | 1.3.1 (L1) Ensure the 'Password expiration policy' is set to 'Set passwords to never expire (recommended)' |
| TBD | 1.3.2 (L1) Ensure 'Idle session timeout' is set to '3 hours (or less)' for unmanaged devices |
| [Test-MtCisCalendarSharing](/docs/commands/) | 1.3.3 (L2) Ensure 'External sharing' of calendars is not available |
| TBD (MT.1041) | 1.3.4 (L1) Ensure 'User owned apps and services' is restricted |
| TBD | 1.3.5 (L1) Ensure internal phishing protection for Forms is enabled |
| [Test-MtCisCustomerLockBox](/docs/commands/) | 1.3.6 (L2) Ensure the customer lockbox feature is enabled |
| TBD (MT.1040) | 1.3.7 (L2) Ensure 'third-party storage services' are restricted in 'Microsoft 365 on the web' |
| TBD | 1.3.8 (L2) Ensure that Sways cannot be shared with people outside of your organization |
| [Test-MtCisSafeLink](/docs/commands/) | 2.1.1 (L2) Ensure Safe Links for Office Applications is Enabled |
| [Test-MtCisAttachmentFilter](/docs/commands/) | 2.1.2 (L1) Ensure the Common Attachment Types Filter is enabled |
| [Test-MtCisInternalMalwareNotification](/docs/commands/) | 2.1.3 (L1) Ensure notifications for internal users sending malware is Enabled |
| [Test-MtCisSafeAttachment](/docs/commands/) | 2.1.4 (L2) Ensure Safe Attachments policy is enabled |
| [Test-MtCisSafeAttachmentsAtpPolicy](/docs/commands/) | 2.1.5 (L2) Ensure Safe Attachments for SharePoint, OneDrive, and Microsoft Teams is Enabled |
| [Test-MtCisOutboundSpamFilterPolicy](/docs/commands/) | 2.1.6 (L1) Ensure Exchange Online Spam Policies are set to notify administrators |
| [Test-MtCisSafeAntiPhishingPolicy](/docs/commands/) | 2.1.7 (L1) Ensure that an anti-phishing policy has been created |
| TBD | 2.1.8 (L1) Ensure that SPF records are published for all Exchange Domains |
| [Test-MtCisDkim](/docs/commands/) | 2.1.9 (L1) Ensure that DKIM is enabled for all Exchange Online Domains |
| TBD | 2.1.10 (L1) Ensure DMARC Records for all Exchange Online domains are published |
| N/A | 2.1.11 (L1) Ensure the spoofed domains report is reviewed weekly |
| N/A | 2.1.12 (L1) Ensure the 'Restricted entities' report is reviewed weekly |
| N/A | 2.1.13 (L1) Ensure malware trends are reviewed at least weekly |
| [Test-MtCisAttachmentFilterComprehensive](/docs/commands/) | 2.1.14 (L2) Ensure comprehensive attachment filtering is applied |
| N/A | 2.3.1 (L1) Ensure the Account Provisioning Activity report is reviewed at least weekly |
| N/A | 2.3.2 (L1) Ensure non-global administrator role group assignments are reviewed at least weekly |
| TBD | 2.4.1 (L1) Ensure Priority account protection is enabled and configured |
| TBD | 2.4.2 (L1) Ensure Priority accounts have 'Strict protection' presets applied |
| TBD | 2.4.3 (L2) Ensure Microsoft Defender for Cloud Apps is enabled and configured |
| [Test-MtCisZAP](/docs/commands/) | 2.4.4 (L1) Ensure Zero-hour auto purge for Microsoft Teams is on |
