---
id: overview
title: CIS Microsoft 365 Foundations Benchmark Tests
sidebar_label: 🌀 CIS
description: Implementation of CIS Microsoft 365 Foundations Benchmark Controls
---

# CIS Microsoft 365 Foundations Benchmark

## Overview

The tests in this section verifies that a Microsoft 365 tenant's configuration conforms to the [CIS Microsoft 365 Foundations Benchmark](https://www.cisecurity.org/benchmark/microsoft_365) recommendations (v5.0.0).

The CIS published material is shared for these tests as it aligns with their licensing of [CC BY-NC-SA 4.0](https://www.cisecurity.org/terms-and-conditions-table-of-contents).

## Connecting to Azure, Exchange and other services

In order to run all the CIS tests, you need to install and connect to the Azure and Exchange Online modules.

See the [Installation guide](/docs/installation#optional-modules-and-permissions) for more information.

## Tests

It is important to note that a number of the policy checks ONLY check the default policy, and not every policy. CIS 2.1.7 `Test-MtCisSafeAntiPhishingPolicy` is one example.

:::info
TBD below refers to CIS "manual" checks. It might be possible to automate these, but skipping for now to focus on automated checks.
N/A below refers to review checks which cannot be automated.
Obsolete below refers to a check which is no longer valid or required.
:::

| Cmdlet Name | CIS Recommendation ID |
| - | - |
| [Test-MtCisCloudAdmin](/docs/commands/Test-MtCisCloudAdmin) | 1.1.1 (L1) Ensure Administrative accounts are cloud-only |
| TBD | 1.1.2 (L1) Ensure two emergency access accounts have been defined |
| [Test-MtCisGlobalAdminCount](/docs/commands/) | 1.1.3 (L1) Ensure that between two and four global admins are designated |
| TBD | 1.1.4 (L1) Ensure administrative accounts use licenses with a reduced application footprint |
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
| [Test-MtCisAttachmentFilterComprehensive](/docs/commands/) | | 2.1.11 (L2) Ensure comprehensive attachment filtering is applied |
| [Test-MtCisHostedConnectionFilterPolicy](/docs/commands/) | 2.1.12 (L1) Ensure the connection filter IP allow list is not used |
| [Test-MtCisConnectionFilterSafeList](/docs/commands/) | 2.1.13 (L1) Ensure the connection filter safe list is off |
| TBD | 2.1.14 (L1) Ensure inbound anti-spam policies do not contain allowed domains |
| TBD | 2.4.1 (L1) Ensure Priority account protection is enabled and configured |
| TBD | 2.4.2 (L1) Ensure Priority accounts have 'Strict protection' presets applied |
| TBD | 2.4.3 (L2) Ensure Microsoft Defender for Cloud Apps is enabled and configured |
| [Test-MtCisZAP](/docs/commands/) | 2.4.4 (L1) Ensure Zero-hour auto purge for Microsoft Teams is on |
| [Test-MtCisAuditLogSearch](/docs/commands/) | 3.1.1 (L1) Ensure Microsoft 365 audit log search is Enabled |
| TBD | 3.2.1 (L1) Ensure DLP policies are enabled |
| TBD | 3.2.2 (L1) Ensure DLP policies are enabled for Microsoft Teams |
| TBD | 3.3.1 (L1) Ensure Information Protection sensitivity label policies are published |
| TBD | 4.1 (L2) Ensure devices without a compliance policy are marked 'not compliant' |
| TBD | 4.2 (L2) Ensure device enrollment for personally owned devices is blocked by default |
| TBD | 5.1.2.1 (L1) Ensure 'Per-user MFA' is disabled |
| TBD | 5.1.2.2 (L2) Ensure third party integrated applications are not allowed |
| TBD | 5.1.2.3 (L1) Ensure 'Restrict non-admin users from creating tenants' is set to 'Yes' |
| TBD | 5.1.2.4 (L1) Ensure access to the Entra admin center is restricted |
| TBD | 5.1.2.5 (L2) Ensure the option to remain signed in is hidden |
| TBD | 5.1.2.6 (L2) Ensure 'LinkedIn account connections' is disabled |
| TBD | 5.1.3.1 (L1) Ensure a dynamic group for guest users is created |
| TBD | 5.1.5.1 (L2) Ensure user consent to apps accessing company data on their behalf is not allowed |
| TBD | 5.1.5.2 (L1) Ensure the admin consent workflow is enabled |
| TBD | 5.1.6.1 (L2) Ensure that collaboration invitations are sent to allowed domains only |
| TBD | 5.1.6.2 (L1) Ensure that guest user access is restricted |
| TBD | 5.1.6.3 (L2) Ensure guest user invitations are limited to the Guest Inviter role |
| TBD | 5.1.8.1 (L1) Ensure that password hash sync is enabled for hybrid deployments |
| TBD | 5.2.2.1 (L1) Ensure multifactor authentication is enabled for all users in administrative roles |
| TBD | 5.2.2.2 (L1) Ensure multifactor authentication is enabled for all users |
| TBD | 5.2.2.3 (L1) Enable Conditional Access policies to block legacy authentication |
| TBD | 5.2.2.4 (L1) Ensure Sign-in frequency is enabled and browser sessions are not persistent for Administrative users |
| TBD | 5.2.2.5 (L2) Ensure 'Phishing-resistant MFA strength' is required for Administrators |
| TBD | 5.2.2.6 (L1) Enable Identity Protection user risk policies |
| TBD | 5.2.2.7 (L1) Enable Identity Protection sign-in risk policies |
| TBD | 5.2.2.8 (L2) Ensure 'sign-in risk' is blocked for medium and high risk |
| TBD | 5.2.2.9 (L1) Ensure a managed device is required for authentication |
| TBD | 5.2.2.10 (L1) Ensure a managed device is required for MFA registration |
| TBD | 5.2.2.11 (L1) Ensure sign-in frequency for Intune Enrollment is set to 'Every time'|
| TBD | 5.2.2.12 (L1) Ensure the device code sign-in flow is blocked |
| TBD | 5.2.3.1 (L1) Ensure Microsoft Authenticator is configured to protect against MFA fatigue |
| TBD | 5.2.3.2 (L1) Ensure custom banned passwords lists are used |
| TBD | 5.2.3.3 (L1) Ensure password protection is enabled for on-prem Active Directory |
| TBD | 5.2.3.4 (L1) Ensure all member users are 'MFA capable' |
| TBD | 5.2.3.5 (L1) Ensure weak authentication methods are disabled |
| TBD | 5.2.3.6 (L1) Ensure system-preferred multifactor authentication is enabled |
| TBD | 5.2.4.1 (L1) Ensure 'Self service password reset enabled' is set to 'All' |
| TBD | 5.3.1 (L2) Ensure 'Privileged Identity Management' is used to manage roles |
| TBD | 5.3.2 (L1) Ensure 'Access reviews' for Guest Users are configured |
| TBD | 5.3.3 (L1) Ensure 'Access reviews' for privileged roles are configured |
| TBD | 5.3.4 (L1) Ensure approval is required for Global Administrator role activation |
| TBD | 5.3.5 (L1) Ensure approval is required for Privileged Role Administrator activation |
| TBD | 6.1.1 (L1) Ensure 'AuditDisabled' organizationally is set to 'False' |
| TBD | 6.1.2 (L1) Ensure mailbox audit actions are configured |
| TBD | 6.1.3 (L1) Ensure 'AuditBypassEnabled' is not enabled on mailboxes |
| TBD | 6.2.1 (L1) Ensure all forms of mail forwarding are blocked and/or disabled |
| TBD | 6.2.2 (L1) Ensure mail transport rules do not whitelist specific domains |
| TBD | 6.2.3 (L1) Ensure email from external senders is identified |
| TBD | 6.3.1 (L2) Ensure users installing Outlook add-ins is not allowed |
| TBD | 6.5.1 (L1) Ensure modern authentication for Exchange Online is enabled |
| TBD | 6.5.2 (L1) Ensure MailTips are enabled for end users |
| TBD | 6.5.3 (L2) Ensure additional storage providers are restricted in Outlook on the web |
| TBD | 6.5.4 (L1) Ensure SMTP AUTH is disabled |
| TBD | 7.2.1 (L1) Ensure modern authentication for SharePoint applications is required |
| TBD | 7.2.2 (L1) Ensure SharePoint and OneDrive integration with Azure AD B2B is enabled |
| TBD | 7.2.3 (L1) Ensure external content sharing is restricted |
| TBD | 7.2.4 (L2) Ensure OneDrive content sharing is restricted |
| TBD | 7.2.5 (L2) Ensure that SharePoint guest users cannot share items they don't own |
| TBD | 7.2.6 (L2) Ensure SharePoint external sharing is managed through domain whitelist/blacklists |
| TBD | 7.2.7 (L1) Ensure link sharing is restricted in SharePoint and OneDrive |
| TBD | 7.2.8 (L2) Ensure external sharing is restricted by security group |
| TBD | 7.2.9 (L1) Ensure guest access to a site or OneDrive will expire automatically |
| TBD | 7.2.10 (L1) Ensure reauthentication with verification code is restricted |
| TBD | 7.2.11 (L1) Ensure the SharePoint default sharing link permission is set |
| TBD | 7.3.1 (L2) Ensure Office 365 SharePoint infected files are disallowed for download |
| TBD | 7.3.2 (L2) Ensure OneDrive sync is restricted for unmanaged devices |
| TBD | 7.3.3 (L1) Ensure custom script execution is restricted on personal sites |
| TBD | 7.3.4 (L1) Ensure custom script execution is restricted on site collections |
| [Test-MtCisThirdPartyFileSharing](/docs/commands/) | 8.1.1 (L2) Ensure external file sharing in Teams is enabled for only approved cloud storage services |
| TBD | 8.1.2 (L1) Ensure users can't send emails to a channel email address |
| TBD | 8.2.1 (L2) Ensure external domains are restricted in the Teams admin center |
| [Test-MtCisCommunicateWithUnmanagedTeamsUsers](/docs/commands/) | 8.2.2 (L1) Ensure communication with unmanaged Teams users is disabled |
| [Test-MtCisCommunicateWithUnmanagedTeamsUsers](/docs/commands/) | 8.2.3 (L1) Ensure external Teams users cannot initiate conversations |
| Obsolete | 8.2.4 (L1) Ensure communication with Skype users is disabled |
| [Test-MtCisThirdPartyAndCustomApps](/docs/commands/) | 8.4.1 (L1) Ensure app permission policies are configured |
| TBD | 8.5.1 (L2) Ensure anonymous users can't join a meeting |
| TBD | 8.5.2 (L1) Ensure anonymous users and dial-in callers can't start a meeting |
| [Test-MtCisTeamsLobbyBypass](/docs/commands/) | 8.5.3 (L1) Ensure only people in my org can bypass the lobby |
| TBD | 8.5.4 (L1) Ensure users dialing in can't bypass the lobby |
| TBD | 8.5.5 (L2) Ensure meeting chat does not allow anonymous users |
| TBD | 8.5.6 (L2) Ensure only organizers and co-organizers can present |
| TBD | 8.5.7 (L1) Ensure external participants can't give or request control |
| TBD | 8.5.8 (L2) Ensure external meeting chat is off |
| TBD | 8.5.9 (L2) Ensure meeting recording is off by default |
| [Test-MtCisTeamsReportSecurityConcerns](/docs/commands/) | 8.6.1 (L1) Ensure users can report security concerns in Teams |
| TBD | 9.1.1 (L1) Ensure guest user access is restricted |
| TBD | 9.1.2 (L1) Ensure external user invitations are restricted |
| TBD | 9.1.3 (L1) Ensure guest access to content is restricted |
| TBD | 9.1.4 (L1) Ensure 'Publish to web' is restricted |
| TBD | 9.1.5 (L2) Ensure 'Interact with and share R and Python' visuals is 'Disabled' |
| TBD | 9.1.6 (L1) Ensure 'Allow users to apply sensitivity labels for content' is 'Enabled' |
| TBD | 9.1.7 (L1) Ensure shareable links are restricted |
| TBD | 9.1.8 (L1) Ensure enabling of external data sharing is restricted |
| TBD | 9.1.9 (L1) Ensure 'Block ResourceKey Authentication' is 'Enabled' |
| TBD | 9.1.10 (L1) Ensure access to APIs by Service Principals is restricted |
| TBD | 9.1.11 (L1) Ensure Service Principals cannot create and use profiles |

