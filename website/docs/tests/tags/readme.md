---
id: overview
title: Tags Overview
sidebar_label: 🏷️ Tags
description: Overview of the tags used to identify and group related tests.
---

## Tags Overview

Tags are used by Maester to identify and group tests.

## Tags Used

The tables below list every tag discovered via `Get-MtTestInventory`. Counts reflect how many individual tests currently carry each tag. Descriptions reuse the first test name associated with the tag.

### CIS Benchmarks

| Tag | Description | Count |
| --- | --- | --- |
| CIS | CIS.M365.1.2.1: Ensure that only organizationally managed/approved public groups exist | 26 |
| CIS E3 | CIS.M365.1.2.1: Ensure that only organizationally managed/approved public groups exist | 16 |
| CIS E3 Level 1 | CIS.M365.2.1.2: Ensure the Common Attachment Types Filter is enabled (Only Checks Default Policy) | 15 |
| CIS E3 Level 2 | CIS.M365.1.2.1: Ensure that only organizationally managed/approved public groups exist | 4 |
| CIS E5 | CIS.M365.1.3.6: Ensure the customer lockbox feature is enabled | 7 |
| CIS E5 Level 1 | CIS.M365.2.1.7: Ensure that an anti-phishing policy has been created (Only Checks Default Policy) | 2 |
| CIS E5 Level 2 | CIS.M365.1.3.6: Ensure the customer lockbox feature is enabled | 5 |
| CIS M365 v5.0.0 | CIS.M365.1.2.1: Ensure that only organizationally managed/approved public groups exist | 26 |
| CIS.M365.1.1.1 | CIS.M365.1.1.1: Ensure Administrative accounts are cloud-only | 1 |
| CIS.M365.1.1.3 | CIS.M365.1.1.3: Ensure that between two and four global admins are designated | 1 |
| CIS.M365.1.2.1 | CIS.M365.1.2.1: Ensure that only organizationally managed/approved public groups exist | 1 |
| CIS.M365.1.2.2 | CIS.M365.1.2.2: Ensure sign-in to shared mailboxes is blocked | 1 |
| CIS.M365.1.3.1 | CIS.M365.1.3.1: Ensure the 'Password expiration policy' is set to 'Set passwords to never expire (recommended)' | 1 |
| CIS.M365.1.3.3 | CIS.M365.1.3.3: Ensure 'External sharing' of calendars is not available | 1 |
| CIS.M365.1.3.6 | CIS.M365.1.3.6: Ensure the customer lockbox feature is enabled | 2 |
| CIS.M365.2.1.1 | CIS.M365.2.1.1: Ensure Safe Links for Office Applications is Enabled (Only Checks Priority 0 Policy) | 1 |
| CIS.M365.2.1.11 | CIS.M365.2.1.11: Ensure comprehensive attachment filtering is applied | 1 |
| CIS.M365.2.1.12 | CIS.M365.2.1.12: Ensure the connection filter IP allow list is not used (Only Checks Default Policy) | 1 |
| CIS.M365.2.1.13 | CIS.M365.2.1.13: Ensure the connection filter safe list is off (Only Checks Default Policy) | 1 |
| CIS.M365.2.1.2 | CIS.M365.2.1.2: Ensure the Common Attachment Types Filter is enabled (Only Checks Default Policy) | 1 |
| CIS.M365.2.1.3 | CIS.M365.2.1.3: Ensure notifications for internal users sending malware is Enabled (Only Checks Default Policy) | 1 |
| CIS.M365.2.1.4 | CIS.M365.2.1.4: Ensure Safe Attachments policy is enabled (Only Checks Default Policy) | 1 |
| CIS.M365.2.1.5 | CIS.M365.2.1.5: Ensure Safe Attachments for SharePoint, OneDrive, and Microsoft Teams is Enabled | 1 |
| CIS.M365.2.1.6 | CIS.M365.2.1.6: Ensure Exchange Online Spam Policies are set to notify administrators (Only Checks Default Policy) | 1 |
| CIS.M365.2.1.7 | CIS.M365.2.1.7: Ensure that an anti-phishing policy has been created (Only Checks Default Policy) | 1 |
| CIS.M365.2.1.9 | CIS.M365.2.1.9: Ensure that DKIM is enabled for all Exchange Online Domains | 1 |
| CIS.M365.2.4.4 | CIS.M365.2.4.4: Ensure Zero-hour auto purge for Microsoft Teams is on (Only Checks ZAP is enabled) | 1 |
| CIS.M365.3.1.1 | CIS.M365.3.1.1: Ensure Microsoft 365 audit log search is Enabled | 1 |
| CIS.M365.8.1.1 | CIS.M365.8.1.1: Ensure external file sharing in Teams is enabled for only approved cloud storage services | 1 |
| CIS.M365.8.2.2 | CIS.M365.8.2.2: Ensure communication with unmanaged Teams users is disabled | 1 |
| CIS.M365.8.4.1 | CIS.M365.8.4.1: Ensure all or a majority of third-party and custom apps are blocked | 1 |
| CIS.M365.8.5.3 | CIS.M365.8.5.3: Ensure only people in my org can bypass the lobby | 1 |
| CIS.M365.8.6.1 | CIS.M365.8.6.1: Ensure users can report security concerns in Teams to internal destination | 1 |

### CISA Baseline

| Tag | Description | Count |
| --- | --- | --- |
| CISA | CISA.MS.AAD.7.8: User activation of the Global Administrator role SHALL trigger an alert. | 73 |
| CISA.MS.AAD.1.1 | CISA.MS.AAD.1.1: Legacy authentication SHALL be blocked. | 1 |
| CISA.MS.AAD.2.1 | CISA.MS.AAD.2.1: Users detected as high risk SHALL be blocked. | 1 |
| CISA.MS.AAD.2.2 | CISA.MS.AAD.2.2: A notification SHOULD be sent to the administrator when high-risk users are detected. | 1 |
| CISA.MS.AAD.2.3 | CISA.MS.AAD.2.3: Sign-ins detected as high risk SHALL be blocked. | 1 |
| CISA.MS.AAD.3.1 | CISA.MS.AAD.3.1: Phishing-resistant MFA SHALL be enforced for all users. | 1 |
| CISA.MS.AAD.3.2 | CISA.MS.AAD.3.2: If phishing-resistant MFA has not been enforced, an alternative MFA method SHALL be enforced for all users. | 1 |
| CISA.MS.AAD.3.3 | CISA.MS.AAD.3.3: If Microsoft Authenticator is enabled, it SHALL be configured to show login context information. | 1 |
| CISA.MS.AAD.3.4 | CISA.MS.AAD.3.4: The Authentication Methods Manage Migration feature SHALL be set to Migration Complete. | 1 |
| CISA.MS.AAD.3.5 | CISA.MS.AAD.3.5: The authentication methods SMS, Voice Call, and Email One-Time Passcode (OTP) SHALL be disabled. | 1 |
| CISA.MS.AAD.3.6 | CISA.MS.AAD.3.6: Phishing-resistant MFA SHALL be required for highly privileged roles. | 1 |
| CISA.MS.AAD.3.7 | CISA.MS.AAD.3.7: Managed devices SHOULD be required for authentication. | 1 |
| CISA.MS.AAD.3.8 | CISA.MS.AAD.3.8: Managed Devices SHOULD be required to register MFA. | 1 |
| CISA.MS.AAD.4.1 | CISA.MS.AAD.4.1: Security logs SHALL be sent to the agency's security operations center for monitoring. | 1 |
| CISA.MS.AAD.5.1 | CISA.MS.AAD.5.1: Only administrators SHALL be allowed to register applications. | 1 |
| CISA.MS.AAD.5.2 | CISA.MS.AAD.5.2: Only administrators SHALL be allowed to consent to applications. | 1 |
| CISA.MS.AAD.5.3 | CISA.MS.AAD.5.3: An admin consent workflow SHALL be configured for applications. | 1 |
| CISA.MS.AAD.5.4 | CISA.MS.AAD.5.4: Group owners SHALL NOT be allowed to consent to applications. | 1 |
| CISA.MS.AAD.6.1 | CISA.MS.AAD.6.1: User passwords SHALL NOT expire. | 1 |
| CISA.MS.AAD.7.1 | CISA.MS.AAD.7.1: A minimum of two users and a maximum of eight users SHALL be provisioned with the Global Administrator role. | 1 |
| CISA.MS.AAD.7.2 | CISA.MS.AAD.7.2: Privileged users SHALL be provisioned with finer-grained roles instead of Global Administrator. | 1 |
| CISA.MS.AAD.7.3 | CISA.MS.AAD.7.3: Privileged users SHALL be provisioned cloud-only accounts separate from an on-premises directory or other federated identity providers. | 1 |
| CISA.MS.AAD.7.4 | CISA.MS.AAD.7.4: Permanent active role assignments SHALL NOT be allowed for highly privileged roles. | 1 |
| CISA.MS.AAD.7.5 | CISA.MS.AAD.7.5: Provisioning users to highly privileged roles SHALL NOT occur outside of a PAM system. | 1 |
| CISA.MS.AAD.7.6 | CISA.MS.AAD.7.6: Activation of the Global Administrator role SHALL require approval. | 1 |
| CISA.MS.AAD.7.7 | CISA.MS.AAD.7.7: Eligible and Active highly privileged role assignments SHALL trigger an alert. | 1 |
| CISA.MS.AAD.7.8 | CISA.MS.AAD.7.8: User activation of the Global Administrator role SHALL trigger an alert. | 1 |
| CISA.MS.AAD.7.9 | CISA.MS.AAD.7.9: User activation of other highly privileged roles SHOULD trigger an alert. | 1 |
| CISA.MS.AAD.8.1 | CISA.MS.AAD.8.1: Guest users SHOULD have limited or restricted access to Entra ID directory objects. | 1 |
| CISA.MS.AAD.8.2 | CISA.MS.AAD.8.2: Only users with the Guest Inviter role SHOULD be able to invite guest users. | 1 |
| CISA.MS.AAD.8.3 | CISA.MS.AAD.8.3: Guest invites SHOULD only be allowed to specific external domains that have been authorized by the agency for legitimate business purposes. | 1 |
| CISA.MS.EXO.1.1 | CISA.MS.EXO.1.1: Automatic forwarding to external domains SHALL be disabled. | 1 |
| CISA.MS.EXO.10.1 | CISA.MS.EXO.10.1: Emails SHALL be scanned for malware. | 1 |
| CISA.MS.EXO.10.2 | CISA.MS.EXO.10.2: Emails identified as containing malware SHALL be quarantined or dropped. | 1 |
| CISA.MS.EXO.10.3 | CISA.MS.EXO.10.3: Email scanning SHALL be capable of reviewing emails after delivery. | 1 |
| CISA.MS.EXO.11.1 | CISA.MS.EXO.11.1: Impersonation protection checks SHOULD be used. | 1 |
| CISA.MS.EXO.11.2 | CISA.MS.EXO.11.2: User warnings, comparable to the user safety tips included with EOP, SHOULD be displayed. | 1 |
| CISA.MS.EXO.11.3 | CISA.MS.EXO.11.3: The phishing protection solution SHOULD include an AI-based phishing detection tool comparable to EOP Mailbox Intelligence. | 1 |
| CISA.MS.EXO.12.1 | CISA.MS.EXO.12.1: IP allow lists SHOULD NOT be created. | 1 |
| CISA.MS.EXO.12.2 | CISA.MS.EXO.12.2: Safe lists SHOULD NOT be enabled. | 1 |
| CISA.MS.EXO.13.1 | CISA.MS.EXO.13.1: Mailbox auditing SHALL be enabled. | 1 |
| CISA.MS.EXO.14.1 | CISA.MS.EXO.14.1: A spam filter SHALL be enabled. | 1 |
| CISA.MS.EXO.14.2 | CISA.MS.EXO.14.2: Spam and high confidence spam SHALL be moved to either the junk email folder or the quarantine folder. | 1 |
| CISA.MS.EXO.14.3 | CISA.MS.EXO.14.3: Allowed domains SHALL NOT be added to inbound anti-spam protection policies. | 1 |
| CISA.MS.EXO.14.4 | CISA.MS.EXO.14.4: If a third-party party filtering solution is used, the solution SHOULD offer services comparable to the native spam filtering offered by Microsoft. | 1 |
| CISA.MS.EXO.15.1 | CISA.MS.EXO.15.1: URL comparison with a block-list SHOULD be enabled. | 1 |
| CISA.MS.EXO.15.2 | CISA.MS.EXO.15.2: Direct download links SHOULD be scanned for malware. | 1 |
| CISA.MS.EXO.15.3 | CISA.MS.EXO.15.3: User click tracking SHOULD be enabled. | 1 |
| CISA.MS.EXO.16.1 | CISA.MS.EXO.16.1: Alerts SHALL be enabled. | 1 |
| CISA.MS.EXO.16.2 | CISA.MS.EXO.16.2: Alerts SHOULD be sent to a monitored address or incorporated into a security information and event management (SIEM) system. | 1 |
| CISA.MS.EXO.17.1 | CISA.MS.EXO.17.1: Microsoft Purview Audit (Standard) logging SHALL be enabled. | 1 |
| CISA.MS.EXO.17.2 | CISA.MS.EXO.17.2: Microsoft Purview Audit (Premium) logging SHALL be enabled. | 1 |
| CISA.MS.EXO.17.3 | CISA.MS.EXO.17.3: Audit logs SHALL be maintained for at least the minimum duration dictated by OMB M-21-31 (Appendix C). | 1 |
| CISA.MS.EXO.2.1 | CISA.MS.EXO.2.1: A list of approved IP addresses for sending mail SHALL be maintained. | 1 |
| CISA.MS.EXO.2.2 | CISA.MS.EXO.2.2: An SPF policy SHALL be published for each domain, designating only these addresses as approved senders. | 1 |
| CISA.MS.EXO.3.1 | CISA.MS.EXO.3.1: DKIM SHOULD be enabled for all domains. | 1 |
| CISA.MS.EXO.4.1 | CISA.MS.EXO.4.1: A DMARC policy SHALL be published for every second-level domain. | 1 |
| CISA.MS.EXO.4.2 | CISA.MS.EXO.4.2: The DMARC message rejection option SHALL be p=reject. | 1 |
| CISA.MS.EXO.4.3 | CISA.MS.EXO.4.3: The DMARC point of contact for aggregate reports SHALL include reports@dmarc.cyber.dhs.gov. | 1 |
| CISA.MS.EXO.5.1 | CISA.MS.EXO.5.1: SMTP AUTH SHALL be disabled. | 1 |
| CISA.MS.EXO.6.1 | CISA.MS.EXO.6.1: Contact folders SHALL NOT be shared with all domains. | 1 |
| CISA.MS.EXO.6.2 | CISA.MS.EXO.6.2: Calendar details SHALL NOT be shared with all domains. | 1 |
| CISA.MS.EXO.7.1 | CISA.MS.EXO.7.1: External sender warnings SHALL be implemented. | 1 |
| CISA.MS.EXO.8.1 | CISA.MS.EXO.8.1: A DLP solution SHALL be used. | 1 |
| CISA.MS.EXO.8.2 | CISA.MS.EXO.8.2: The DLP solution SHALL protect personally identifiable information (PII) and sensitive information, as defined by the agency. | 1 |
| CISA.MS.EXO.8.3 | CISA.MS.EXO.8.3: The selected DLP solution SHOULD offer services comparable to the native DLP solution offered by Microsoft. | 1 |
| CISA.MS.EXO.8.4 | CISA.MS.EXO.8.4: At a minimum, the DLP solution SHALL restrict sharing credit card numbers, U.S. Individual Taxpayer Identification Numbers (ITIN), and U.S. Social Security numbers (SSN) via email. | 1 |
| CISA.MS.EXO.9.1 | CISA.MS.EXO.9.1: Emails SHALL be filtered by attachment file types. | 1 |
| CISA.MS.EXO.9.2 | CISA.MS.EXO.9.2: The attachment filter SHOULD attempt to determine the true file type and assess the file extension. | 1 |
| CISA.MS.EXO.9.3 | CISA.MS.EXO.9.3: Disallowed file types SHALL be determined and enforced. | 1 |
| CISA.MS.EXO.9.4 | CISA.MS.EXO.9.4: Alternatively chosen filtering solutions SHOULD offer services comparable to Microsoft Defender's Common Attachment Filter. | 1 |
| CISA.MS.EXO.9.5 | CISA.MS.EXO.9.5: At a minimum, click-to-run files SHOULD be blocked (e.g., .exe, .cmd, and .vbe). | 1 |
| CISA.MS.SHAREPOINT.1.1 | CISA.MS.SHAREPOINT.1.1: External sharing for SharePoint SHALL be limited to Existing guests or Only People in your organization. | 1 |
| CISA.MS.SHAREPOINT.1.3 | CISA.MS.SHAREPOINT.1.3: External sharing SHALL be restricted to approved external domains and/or users in approved security groups per interagency collaboration needs. | 1 |
| MS.AAD | CISA.MS.AAD.7.8: User activation of the Global Administrator role SHALL trigger an alert. | 30 |
| MS.AAD.1.1 | CISA.MS.AAD.1.1: Legacy authentication SHALL be blocked. | 1 |
| MS.AAD.2.1 | CISA.MS.AAD.2.1: Users detected as high risk SHALL be blocked. | 1 |
| MS.AAD.2.2 | CISA.MS.AAD.2.2: A notification SHOULD be sent to the administrator when high-risk users are detected. | 1 |
| MS.AAD.2.3 | CISA.MS.AAD.2.3: Sign-ins detected as high risk SHALL be blocked. | 1 |
| MS.AAD.3.1 | CISA.MS.AAD.3.1: Phishing-resistant MFA SHALL be enforced for all users. | 1 |
| MS.AAD.3.2 | CISA.MS.AAD.3.2: If phishing-resistant MFA has not been enforced, an alternative MFA method SHALL be enforced for all users. | 1 |
| MS.AAD.3.3 | CISA.MS.AAD.3.3: If Microsoft Authenticator is enabled, it SHALL be configured to show login context information. | 1 |
| MS.AAD.3.4 | CISA.MS.AAD.3.4: The Authentication Methods Manage Migration feature SHALL be set to Migration Complete. | 1 |
| MS.AAD.3.5 | CISA.MS.AAD.3.5: The authentication methods SMS, Voice Call, and Email One-Time Passcode (OTP) SHALL be disabled. | 1 |
| MS.AAD.3.6 | CISA.MS.AAD.3.6: Phishing-resistant MFA SHALL be required for highly privileged roles. | 1 |
| MS.AAD.3.7 | CISA.MS.AAD.3.7: Managed devices SHOULD be required for authentication. | 1 |
| MS.AAD.3.8 | CISA.MS.AAD.3.8: Managed Devices SHOULD be required to register MFA. | 1 |
| MS.AAD.4.1 | CISA.MS.AAD.4.1: Security logs SHALL be sent to the agency's security operations center for monitoring. | 1 |
| MS.AAD.5.1 | CISA.MS.AAD.5.1: Only administrators SHALL be allowed to register applications. | 1 |
| MS.AAD.5.2 | CISA.MS.AAD.5.2: Only administrators SHALL be allowed to consent to applications. | 1 |
| MS.AAD.5.3 | CISA.MS.AAD.5.3: An admin consent workflow SHALL be configured for applications. | 1 |
| MS.AAD.5.4 | CISA.MS.AAD.5.4: Group owners SHALL NOT be allowed to consent to applications. | 1 |
| MS.AAD.6.1 | CISA.MS.AAD.6.1: User passwords SHALL NOT expire. | 1 |
| MS.AAD.7.1 | CISA.MS.AAD.7.1: A minimum of two users and a maximum of eight users SHALL be provisioned with the Global Administrator role. | 1 |
| MS.AAD.7.2 | CISA.MS.AAD.7.2: Privileged users SHALL be provisioned with finer-grained roles instead of Global Administrator. | 1 |
| MS.AAD.7.3 | CISA.MS.AAD.7.3: Privileged users SHALL be provisioned cloud-only accounts separate from an on-premises directory or other federated identity providers. | 1 |
| MS.AAD.7.4 | CISA.MS.AAD.7.4: Permanent active role assignments SHALL NOT be allowed for highly privileged roles. | 1 |
| MS.AAD.7.5 | CISA.MS.AAD.7.5: Provisioning users to highly privileged roles SHALL NOT occur outside of a PAM system. | 1 |
| MS.AAD.7.6 | CISA.MS.AAD.7.6: Activation of the Global Administrator role SHALL require approval. | 1 |
| MS.AAD.7.7 | CISA.MS.AAD.7.7: Eligible and Active highly privileged role assignments SHALL trigger an alert. | 1 |
| MS.AAD.7.8 | CISA.MS.AAD.7.8: User activation of the Global Administrator role SHALL trigger an alert. | 1 |
| MS.AAD.7.9 | CISA.MS.AAD.7.9: User activation of other highly privileged roles SHOULD trigger an alert. | 1 |
| MS.AAD.8.1 | CISA.MS.AAD.8.1: Guest users SHOULD have limited or restricted access to Entra ID directory objects. | 1 |
| MS.AAD.8.2 | CISA.MS.AAD.8.2: Only users with the Guest Inviter role SHOULD be able to invite guest users. | 1 |
| MS.AAD.8.3 | CISA.MS.AAD.8.3: Guest invites SHOULD only be allowed to specific external domains that have been authorized by the agency for legitimate business purposes. | 1 |
| MS.EXO | CISA.MS.EXO.12.1: IP allow lists SHOULD NOT be created. | 41 |
| MS.EXO.1.1 | CISA.MS.EXO.1.1: Automatic forwarding to external domains SHALL be disabled. | 1 |
| MS.EXO.10.1 | CISA.MS.EXO.10.1: Emails SHALL be scanned for malware. | 1 |
| MS.EXO.10.2 | CISA.MS.EXO.10.2: Emails identified as containing malware SHALL be quarantined or dropped. | 1 |
| MS.EXO.10.3 | CISA.MS.EXO.10.3: Email scanning SHALL be capable of reviewing emails after delivery. | 1 |
| MS.EXO.11.1 | CISA.MS.EXO.11.1: Impersonation protection checks SHOULD be used. | 1 |
| MS.EXO.11.2 | CISA.MS.EXO.11.2: User warnings, comparable to the user safety tips included with EOP, SHOULD be displayed. | 1 |
| MS.EXO.11.3 | CISA.MS.EXO.11.3: The phishing protection solution SHOULD include an AI-based phishing detection tool comparable to EOP Mailbox Intelligence. | 1 |
| MS.EXO.12.1 | CISA.MS.EXO.12.1: IP allow lists SHOULD NOT be created. | 1 |
| MS.EXO.12.2 | CISA.MS.EXO.12.2: Safe lists SHOULD NOT be enabled. | 1 |
| MS.EXO.13.1 | CISA.MS.EXO.13.1: Mailbox auditing SHALL be enabled. | 1 |
| MS.EXO.14.1 | CISA.MS.EXO.14.1: A spam filter SHALL be enabled. | 1 |
| MS.EXO.14.2 | CISA.MS.EXO.14.2: Spam and high confidence spam SHALL be moved to either the junk email folder or the quarantine folder. | 1 |
| MS.EXO.14.3 | CISA.MS.EXO.14.3: Allowed domains SHALL NOT be added to inbound anti-spam protection policies. | 1 |
| MS.EXO.14.4 | CISA.MS.EXO.14.4: If a third-party party filtering solution is used, the solution SHOULD offer services comparable to the native spam filtering offered by Microsoft. | 1 |
| MS.EXO.15.1 | CISA.MS.EXO.15.1: URL comparison with a block-list SHOULD be enabled. | 1 |
| MS.EXO.15.2 | CISA.MS.EXO.15.2: Direct download links SHOULD be scanned for malware. | 1 |
| MS.EXO.15.3 | CISA.MS.EXO.15.3: User click tracking SHOULD be enabled. | 1 |
| MS.EXO.16.1 | CISA.MS.EXO.16.1: Alerts SHALL be enabled. | 1 |
| MS.EXO.16.2 | CISA.MS.EXO.16.2: Alerts SHOULD be sent to a monitored address or incorporated into a security information and event management (SIEM) system. | 1 |
| MS.EXO.17.1 | CISA.MS.EXO.17.1: Microsoft Purview Audit (Standard) logging SHALL be enabled. | 1 |
| MS.EXO.17.2 | CISA.MS.EXO.17.2: Microsoft Purview Audit (Premium) logging SHALL be enabled. | 1 |
| MS.EXO.17.3 | CISA.MS.EXO.17.3: Audit logs SHALL be maintained for at least the minimum duration dictated by OMB M-21-31 (Appendix C). | 1 |
| MS.EXO.2.1 | CISA.MS.EXO.2.1: A list of approved IP addresses for sending mail SHALL be maintained. | 1 |
| MS.EXO.2.2 | CISA.MS.EXO.2.2: An SPF policy SHALL be published for each domain, designating only these addresses as approved senders. | 1 |
| MS.EXO.3.1 | CISA.MS.EXO.3.1: DKIM SHOULD be enabled for all domains. | 1 |
| MS.EXO.4.1 | CISA.MS.EXO.4.1: A DMARC policy SHALL be published for every second-level domain. | 1 |
| MS.EXO.4.2 | CISA.MS.EXO.4.2: The DMARC message rejection option SHALL be p=reject. | 1 |
| MS.EXO.4.3 | CISA.MS.EXO.4.3: The DMARC point of contact for aggregate reports SHALL include reports@dmarc.cyber.dhs.gov. | 1 |
| MS.EXO.5.1 | CISA.MS.EXO.5.1: SMTP AUTH SHALL be disabled. | 1 |
| MS.EXO.6.1 | CISA.MS.EXO.6.1: Contact folders SHALL NOT be shared with all domains. | 1 |
| MS.EXO.6.2 | CISA.MS.EXO.6.2: Calendar details SHALL NOT be shared with all domains. | 1 |
| MS.EXO.7.1 | CISA.MS.EXO.7.1: External sender warnings SHALL be implemented. | 1 |
| MS.EXO.8.1 | CISA.MS.EXO.8.1: A DLP solution SHALL be used. | 1 |
| MS.EXO.8.2 | CISA.MS.EXO.8.2: The DLP solution SHALL protect personally identifiable information (PII) and sensitive information, as defined by the agency. | 1 |
| MS.EXO.8.3 | CISA.MS.EXO.8.3: The selected DLP solution SHOULD offer services comparable to the native DLP solution offered by Microsoft. | 1 |
| MS.EXO.8.4 | CISA.MS.EXO.8.4: At a minimum, the DLP solution SHALL restrict sharing credit card numbers, U.S. Individual Taxpayer Identification Numbers (ITIN), and U.S. Social Security numbers (SSN) via email. | 1 |
| MS.EXO.9.1 | CISA.MS.EXO.9.1: Emails SHALL be filtered by attachment file types. | 1 |
| MS.EXO.9.2 | CISA.MS.EXO.9.2: The attachment filter SHOULD attempt to determine the true file type and assess the file extension. | 1 |
| MS.EXO.9.3 | CISA.MS.EXO.9.3: Disallowed file types SHALL be determined and enforced. | 1 |
| MS.EXO.9.4 | CISA.MS.EXO.9.4: Alternatively chosen filtering solutions SHOULD offer services comparable to Microsoft Defender's Common Attachment Filter. | 1 |
| MS.EXO.9.5 | CISA.MS.EXO.9.5: At a minimum, click-to-run files SHOULD be blocked (e.g., .exe, .cmd, and .vbe). | 1 |
| MS.SHAREPOINT | CISA.MS.SHAREPOINT.1.1: External sharing for SharePoint SHALL be limited to Existing guests or Only People in your organization. | 2 |
| MS.SHAREPOINT.1.1 | CISA.MS.SHAREPOINT.1.1: External sharing for SharePoint SHALL be limited to Existing guests or Only People in your organization. | 1 |
| MS.SHAREPOINT.1.3 | CISA.MS.SHAREPOINT.1.3: External sharing SHALL be restricted to approved external domains and/or users in approved security groups per interagency collaboration needs. | 1 |

### EIDSCA (Entra ID Security Configuration Analyzer)

| Tag | Description | Count |
| --- | --- | --- |
| EIDSCA | EIDSCA.AP01: Default Authorization Settings - Enabled Self service password reset for administrators. See https://maester.dev/docs/tests/EIDSCA.AP01 | 44 |
| EIDSCA.AF01 | EIDSCA.AF01: Authentication Method - FIDO2 security key - State. See https://maester.dev/docs/tests/EIDSCA.AF01 | 1 |
| EIDSCA.AF02 | EIDSCA.AF02: Authentication Method - FIDO2 security key - Allow self-service set up. See https://maester.dev/docs/tests/EIDSCA.AF02 | 1 |
| EIDSCA.AF03 | EIDSCA.AF03: Authentication Method - FIDO2 security key - Enforce attestation. See https://maester.dev/docs/tests/EIDSCA.AF03 | 1 |
| EIDSCA.AF04 | EIDSCA.AF04: Authentication Method - FIDO2 security key - Enforce key restrictions. See https://maester.dev/docs/tests/EIDSCA.AF04 | 1 |
| EIDSCA.AF05 | EIDSCA.AF05: Authentication Method - FIDO2 security key - Restricted. See https://maester.dev/docs/tests/EIDSCA.AF05 | 1 |
| EIDSCA.AF06 | EIDSCA.AF06: Authentication Method - FIDO2 security key - Restrict specific keys. See https://maester.dev/docs/tests/EIDSCA.AF06 | 1 |
| EIDSCA.AG01 | EIDSCA.AG01: Authentication Method - General Settings - Manage migration. See https://maester.dev/docs/tests/EIDSCA.AG01 | 1 |
| EIDSCA.AG02 | EIDSCA.AG02: Authentication Method - General Settings - Report suspicious activity - State. See https://maester.dev/docs/tests/EIDSCA.AG02 | 1 |
| EIDSCA.AG03 | EIDSCA.AG03: Authentication Method - General Settings - Report suspicious activity - Included users/groups. See https://maester.dev/docs/tests/EIDSCA.AG03 | 1 |
| EIDSCA.AM01 | EIDSCA.AM01: Authentication Method - Microsoft Authenticator - State. See https://maester.dev/docs/tests/EIDSCA.AM01 | 1 |
| EIDSCA.AM02 | EIDSCA.AM02: Authentication Method - Microsoft Authenticator - Allow use of Microsoft Authenticator OTP. See https://maester.dev/docs/tests/EIDSCA.AM02 | 1 |
| EIDSCA.AM03 | EIDSCA.AM03: Authentication Method - Microsoft Authenticator - Require number matching for push notifications. See https://maester.dev/docs/tests/EIDSCA.AM03 | 1 |
| EIDSCA.AM04 | EIDSCA.AM04: Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications. See https://maester.dev/docs/tests/EIDSCA.AM04 | 1 |
| EIDSCA.AM06 | EIDSCA.AM06: Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.AM06 | 1 |
| EIDSCA.AM07 | EIDSCA.AM07: Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.AM07 | 1 |
| EIDSCA.AM09 | EIDSCA.AM09: Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.AM09 | 1 |
| EIDSCA.AM10 | EIDSCA.AM10: Authentication Method - Microsoft Authenticator - Included users/groups to show geographic location in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.AM10 | 1 |
| EIDSCA.AP01 | EIDSCA.AP01: Default Authorization Settings - Enabled Self service password reset for administrators. See https://maester.dev/docs/tests/EIDSCA.AP01 | 1 |
| EIDSCA.AP04 | EIDSCA.AP04: Default Authorization Settings - Guest invite restrictions. See https://maester.dev/docs/tests/EIDSCA.AP04 | 1 |
| EIDSCA.AP05 | EIDSCA.AP05: Default Authorization Settings - Sign-up for email based subscription. See https://maester.dev/docs/tests/EIDSCA.AP05 | 1 |
| EIDSCA.AP06 | EIDSCA.AP06: Default Authorization Settings - User can join the tenant by email validation. See https://maester.dev/docs/tests/EIDSCA.AP06 | 1 |
| EIDSCA.AP07 | EIDSCA.AP07: Default Authorization Settings - Guest user access. See https://maester.dev/docs/tests/EIDSCA.AP07 | 1 |
| EIDSCA.AP08 | EIDSCA.AP08: Default Authorization Settings - User consent policy assigned for applications. See https://maester.dev/docs/tests/EIDSCA.AP08 | 1 |
| EIDSCA.AP09 | EIDSCA.AP09: Default Authorization Settings - Allow user consent on risk-based apps. See https://maester.dev/docs/tests/EIDSCA.AP09 | 1 |
| EIDSCA.AP10 | EIDSCA.AP10: Default Authorization Settings - Default User Role Permissions - Allowed to create Apps. See https://maester.dev/docs/tests/EIDSCA.AP10 | 1 |
| EIDSCA.AP14 | EIDSCA.AP14: Default Authorization Settings - Default User Role Permissions - Allowed to read other users. See https://maester.dev/docs/tests/EIDSCA.AP14 | 1 |
| EIDSCA.AS04 | EIDSCA.AS04: Authentication Method - SMS - Use for sign-in. See https://maester.dev/docs/tests/EIDSCA.AS04 | 1 |
| EIDSCA.AT01 | EIDSCA.AT01: Authentication Method - Temporary Access Pass - State. See https://maester.dev/docs/tests/EIDSCA.AT01 | 1 |
| EIDSCA.AT02 | EIDSCA.AT02: Authentication Method - Temporary Access Pass - One-time. See https://maester.dev/docs/tests/EIDSCA.AT02 | 1 |
| EIDSCA.AV01 | EIDSCA.AV01: Authentication Method - Voice call - State. See https://maester.dev/docs/tests/EIDSCA.AV01 | 1 |
| EIDSCA.CP01 | EIDSCA.CP01: Default Settings - Consent Policy Settings - Group owner consent for apps accessing data. See https://maester.dev/docs/tests/EIDSCA.CP01 | 1 |
| EIDSCA.CP03 | EIDSCA.CP03: Default Settings - Consent Policy Settings - Block user consent for risky apps. See https://maester.dev/docs/tests/EIDSCA.CP03 | 1 |
| EIDSCA.CP04 | EIDSCA.CP04: Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to. See https://maester.dev/docs/tests/EIDSCA.CP04 | 1 |
| EIDSCA.CR01 | EIDSCA.CR01: Consent Framework - Admin Consent Request - Policy to enable or disable admin consent request feature. See https://maester.dev/docs/tests/EIDSCA.CR01 | 1 |
| EIDSCA.CR02 | EIDSCA.CR02: Consent Framework - Admin Consent Request - Reviewers will receive email notifications for requests. See https://maester.dev/docs/tests/EIDSCA.CR02 | 1 |
| EIDSCA.CR03 | EIDSCA.CR03: Consent Framework - Admin Consent Request - Reviewers will receive email notifications when admin consent requests are about to expire. See https://maester.dev/docs/tests/EIDSCA.CR03 | 1 |
| EIDSCA.CR04 | EIDSCA.CR04: Consent Framework - Admin Consent Request - Consent request duration (days). See https://maester.dev/docs/tests/EIDSCA.CR04 | 1 |
| EIDSCA.PR01 | EIDSCA.PR01: Default Settings - Password Rule Settings - Password Protection - Mode. See https://maester.dev/docs/tests/EIDSCA.PR01 | 1 |
| EIDSCA.PR02 | EIDSCA.PR02: Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory. See https://maester.dev/docs/tests/EIDSCA.PR02 | 1 |
| EIDSCA.PR03 | EIDSCA.PR03: Default Settings - Password Rule Settings - Enforce custom list. See https://maester.dev/docs/tests/EIDSCA.PR03 | 1 |
| EIDSCA.PR05 | EIDSCA.PR05: Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds. See https://maester.dev/docs/tests/EIDSCA.PR05 | 1 |
| EIDSCA.PR06 | EIDSCA.PR06: Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold. See https://maester.dev/docs/tests/EIDSCA.PR06 | 1 |
| EIDSCA.ST08 | EIDSCA.ST08: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner. See https://maester.dev/docs/tests/EIDSCA.ST08 | 1 |
| EIDSCA.ST09 | EIDSCA.ST09: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content. See https://maester.dev/docs/tests/EIDSCA.ST09 | 1 |

### ORCA (Microsoft Defender for Office 365 Recommended Configuration Analyzer)

| Tag | Description | Count |
| --- | --- | --- |
| ORCA | ORCA.100: Bulk Complaint Level threshold is between 4 and 6. | 67 |
| ORCA.100 | ORCA.100: Bulk Complaint Level threshold is between 4 and 6. | 1 |
| ORCA.101 | ORCA.101: Bulk is marked as spam. | 1 |
| ORCA.102 | ORCA.102: Advanced Spam filter options are turned off. | 1 |
| ORCA.103 | ORCA.103: Outbound spam filter policy settings configured. | 1 |
| ORCA.104 | ORCA.104: High Confidence Phish action set to Quarantine message. | 1 |
| ORCA.105 | ORCA.105: Safe Links Synchronous URL detonation is enabled. | 1 |
| ORCA.106 | ORCA.106: Quarantine retention period is 30 days. | 1 |
| ORCA.107 | ORCA.107: End-user spam notification is enabled. | 1 |
| ORCA.108 | ORCA.108: DKIM signing is set up for all your custom domains. | 1 |
| ORCA.108.1 | ORCA.108.1: DNS Records have been set up to support DKIM. | 1 |
| ORCA.109 | ORCA.109: Senders are not being allow listed in an unsafe manner. | 1 |
| ORCA.110 | ORCA.110: Internal Sender notifications are disabled. | 1 |
| ORCA.111 | ORCA.111: Anti-phishing policy exists and EnableUnauthenticatedSender is true. | 1 |
| ORCA.112 | ORCA.112: Anti-spoofing protection action is configured to Move message to the recipients' Junk Email folders in Anti-phishing policy. | 1 |
| ORCA.113 | ORCA.113: AllowClickThrough is disabled in Safe Links policies. | 1 |
| ORCA.114 | ORCA.114: No IP Allow Lists have been configured. | 1 |
| ORCA.115 | ORCA.115: Mailbox intelligence based impersonation protection is enabled in anti-phishing policies. | 1 |
| ORCA.116 | ORCA.116: Mailbox intelligence based impersonation protection action set to move message to junk mail folder. | 1 |
| ORCA.118.1 | ORCA.118.1: Domains are not being allow listed in an unsafe manner in Anti-Spam Policies. | 1 |
| ORCA.118.2 | ORCA.118.2: Domains are not being allow listed in an unsafe manner in Transport Rules. | 1 |
| ORCA.118.3 | ORCA.118.3: Your own domains are not being allow listed in an unsafe manner in Anti-Spam Policies. | 1 |
| ORCA.118.4 | ORCA.118.4: Your own domains are not being allow listed in an unsafe manner in Transport Rules. | 1 |
| ORCA.119 | ORCA.119: Similar Domains Safety Tips is enabled. | 1 |
| ORCA.120.1 | ORCA.120.1: Zero Hour Autopurge Enabled for Phish. | 1 |
| ORCA.120.2 | ORCA.120.2: Zero Hour Autopurge Enabled for Malware. | 1 |
| ORCA.120.3 | ORCA.120.3: Zero Hour Autopurge Enabled for Spam. | 1 |
| ORCA.121 | ORCA.121: Supported filter policy action used. | 1 |
| ORCA.123 | ORCA.123: Unusual Characters Safety Tips is enabled. | 1 |
| ORCA.124 | ORCA.124: Safe attachments unknown malware response set to block messages. | 1 |
| ORCA.139 | ORCA.139: Spam action set to move message to junk mail folder or quarantine. | 1 |
| ORCA.140 | ORCA.140: High Confidence Spam action set to Quarantine message. | 1 |
| ORCA.141 | ORCA.141: Bulk action set to Move message to Junk Email Folder. | 1 |
| ORCA.142 | ORCA.142: Phish action set to Quarantine message. | 1 |
| ORCA.143 | ORCA.143: Safety Tips are enabled. | 1 |
| ORCA.156 | ORCA.156: Safe Links Policies are tracking when user clicks on safe links. | 1 |
| ORCA.158 | ORCA.158: Safe Attachments is enabled for SharePoint and Teams. | 1 |
| ORCA.179 | ORCA.179: Safe Links is enabled intra-organization. | 1 |
| ORCA.180 | ORCA.180: Anti-phishing policy exists and EnableSpoofIntelligence is true. | 1 |
| ORCA.189 | ORCA.189: Safe Attachments is not bypassed. | 1 |
| ORCA.189.2 | ORCA.189.2: Safe Links is not bypassed. | 1 |
| ORCA.205 | ORCA.205: Common attachment type filter is enabled. | 1 |
| ORCA.220 | ORCA.220: Advanced Phish filter Threshold level is adequate. | 1 |
| ORCA.221 | ORCA.221: Mailbox intelligence is enabled in anti-phishing policies. | 1 |
| ORCA.222 | ORCA.222: Domain Impersonation action is set to move to Quarantine. | 1 |
| ORCA.223 | ORCA.223: User impersonation action is set to move to Quarantine. | 1 |
| ORCA.224 | ORCA.224: Similar Users Safety Tips is enabled. | 1 |
| ORCA.225 | ORCA.225: Safe Documents is enabled for Office clients. | 1 |
| ORCA.226 | ORCA.226: Each domain has a Safe Link policy applied to it. | 1 |
| ORCA.227 | ORCA.227: Each domain has a Safe Attachments policy applied to it. | 1 |
| ORCA.228 | ORCA.228: No trusted senders in Anti-phishing policy. | 1 |
| ORCA.229 | ORCA.229: No trusted domains in Anti-phishing policy. | 1 |
| ORCA.230 | ORCA.230: Each domain has a Anti-phishing policy applied to it, or the default policy is being used. | 1 |
| ORCA.231 | ORCA.231: Each domain has a anti-spam policy applied to it, or the default policy is being used. | 1 |
| ORCA.232 | ORCA.232: Each domain has a malware filter policy applied to it, or the default policy is being used. | 1 |
| ORCA.233 | ORCA.233: Domains are pointed directly at EOP or enhanced filtering is used. | 1 |
| ORCA.233.1 | ORCA.233.1: Domains are pointed directly at EOP or enhanced filtering is configured on all default connectors. | 1 |
| ORCA.234 | ORCA.234: Click through is disabled for Safe Documents. | 1 |
| ORCA.235 | ORCA.235: SPF records is set up for all your custom domains. | 1 |
| ORCA.236 | ORCA.236: Safe Links is enabled for emails. | 1 |
| ORCA.237 | ORCA.237: Safe Links is enabled for teams messages. | 1 |
| ORCA.238 | ORCA.238: Safe Links is enabled for office documents. | 1 |
| ORCA.239 | ORCA.239: No exclusions for the built-in protection policies. | 1 |
| ORCA.240 | ORCA.240: Outlook is configured to display external tags for external emails. | 1 |
| ORCA.241 | ORCA.241: Anti-phishing policy exists and EnableFirstContactSafetyTips is true. | 1 |
| ORCA.242 | ORCA.242: Important protection alerts responsible for AIR activities are enabled. | 1 |
| ORCA.243 | ORCA.243: Authenticated Receive Chain is set up for domains not pointing to EOP/MDO, or all domains point to EOP/MDO. | 1 |
| ORCA.244 | ORCA.244: Policies are configured to honor sending domains DMARC. | 1 |

### Maester

| Tag | Description | Count |
| --- | --- | --- |
| Maester | MT.1002: App management restrictions on applications and service principals is configured and enabled. See https://maester.dev/docs/tests/MT.1002 | 73 |
| Maester/Entra | MT.1002: App management restrictions on applications and service principals is configured and enabled. See https://maester.dev/docs/tests/MT.1002 | 61 |
| Maester/Exchange | MT.1043: Ensure Spam confidence level (SCL) is configured in mail transport rules with specific domains | 9 |
| Maester/Intune | MT.1092: Intune APNS certificate should be valid for more than 30 days | 15 |
| Maester/Teams | MT.1037: Only users with Presenter role are allowed to present in Teams meetings | 6 |
| MT.1001 | MT.1001: At least one Conditional Access policy is configured with device compliance. See https://maester.dev/docs/tests/MT.1001 | 1 |
| MT.1002 | MT.1002: App management restrictions on applications and service principals is configured and enabled. See https://maester.dev/docs/tests/MT.1002 | 1 |
| MT.1003 | MT.1003: At least one Conditional Access policy is configured with All Apps. See https://maester.dev/docs/tests/MT.1003 | 1 |
| MT.1004 | MT.1004: At least one Conditional Access policy is configured with All Apps and All Users. See https://maester.dev/docs/tests/MT.1004 | 1 |
| MT.1005 | MT.1005: All Conditional Access policies are configured to exclude at least one emergency/break glass account or group. See https://maester.dev/docs/tests/MT.1005 | 1 |
| MT.1006 | MT.1006: At least one Conditional Access policy is configured to require MFA for admins. See https://maester.dev/docs/tests/MT.1006 | 1 |
| MT.1007 | MT.1007: At least one Conditional Access policy is configured to require MFA for all users. See https://maester.dev/docs/tests/MT.1007 | 1 |
| MT.1008 | MT.1008: At least one Conditional Access policy is configured to require MFA for Azure management. See https://maester.dev/docs/tests/MT.1008 | 1 |
| MT.1009 | MT.1009: At least one Conditional Access policy is configured to block other legacy authentication. See https://maester.dev/docs/tests/MT.1009 | 1 |
| MT.1010 | MT.1010: At least one Conditional Access policy is configured to block legacy authentication for Exchange ActiveSync. See https://maester.dev/docs/tests/MT.1010 | 1 |
| MT.1011 | MT.1011: At least one Conditional Access policy is configured to secure security info registration only from a trusted location. See https://maester.dev/docs/tests/MT.1011 | 1 |
| MT.1012 | MT.1012: At least one Conditional Access policy is configured to require MFA for risky sign-ins. See https://maester.dev/docs/tests/MT.1012 | 1 |
| MT.1013 | MT.1013: At least one Conditional Access policy is configured to require new password when user risk is high. See https://maester.dev/docs/tests/MT.1013 | 1 |
| MT.1014 | MT.1014: At least one Conditional Access policy is configured to require compliant or Entra hybrid joined devices for admins. See https://maester.dev/docs/tests/MT.1014 | 1 |
| MT.1015 | MT.1015: At least one Conditional Access policy is configured to block access for unknown or unsupported device platforms. See https://maester.dev/docs/tests/MT.1015 | 1 |
| MT.1016 | MT.1016: At least one Conditional Access policy is configured to require MFA for guest access. See https://maester.dev/docs/tests/MT.1016 | 1 |
| MT.1017 | MT.1017: At least one Conditional Access policy is configured to enforce non persistent browser session for non-corporate devices. See https://maester.dev/docs/tests/MT.1017 | 1 |
| MT.1018 | MT.1018: At least one Conditional Access policy is configured to enforce sign-in frequency for non-corporate devices. See https://maester.dev/docs/tests/MT.1018 | 1 |
| MT.1019 | MT.1019: At least one Conditional Access policy is configured to enable application enforced restrictions. See https://maester.dev/docs/tests/MT.1019 | 1 |
| MT.1020 | MT.1020: All Conditional Access policies are configured to exclude directory synchronization accounts or do not scope them. See https://maester.dev/docs/tests/MT.1020 | 1 |
| MT.1021 | MT.1021: Security Defaults are enabled. See https://maester.dev/docs/tests/MT.1021 | 1 |
| MT.1022 | MT.1022: All users utilizing a P1 license should be licensed. See https://maester.dev/docs/tests/MT.1022 | 1 |
| MT.1023 | MT.1023: All users utilizing a P2 license should be licensed. See https://maester.dev/docs/tests/MT.1023 | 1 |
| MT.1024 | MT.1024.: . See https://maester.dev/docs/tests/MT.1024 | 1 |
| MT.1025 | MT.1025: No external user with permanent role assignment on Control Plane. See https://maester.dev/docs/tests/MT.1025 | 1 |
| MT.1026 | MT.1026: No hybrid user with permanent role assignment on Control Plane. See https://maester.dev/docs/tests/MT.1026 | 1 |
| MT.1027 | MT.1027: No Service Principal with Client Secret and permanent role assignment on Control Plane. See https://maester.dev/docs/tests/MT.1027 | 1 |
| MT.1028 | MT.1028: No user with mailbox and permanent role assignment on Control Plane. See https://maester.dev/docs/tests/MT.1028 | 1 |
| MT.1029 | MT.1029: Stale accounts are not assigned to privileged roles. See https://maester.dev/docs/tests/MT.1029 | 1 |
| MT.1030 | MT.1030: Eligible role assignments on Control Plane are in use by administrators. See https://maester.dev/docs/tests/MT.1030 | 1 |
| MT.1031 | MT.1031: Privileged role on Control Plane are managed by PIM only. See https://maester.dev/docs/tests/MT.1031 | 1 |
| MT.1032 | MT.1032: Limited number of Global Admins are assigned. See https://maester.dev/docs/tests/MT.1032 | 1 |
| MT.1033 | MT.1033.0: User should be blocked from using legacy authentication (samerde@daserde.com) | 6 |
| MT.1034 | MT.1034: Emergency access users should not be blocked | 1 |
| MT.1035 | MT.1035: All security groups assigned to Conditional Access Policies should be protected by RMAU. See https://maester.dev/docs/tests/MT.1035 | 1 |
| MT.1036 | MT.1036: All excluded objects should have a fallback include in another policy. See https://maester.dev/docs/tests/MT.1036 | 1 |
| MT.1037 | MT.1037: Only users with Presenter role are allowed to present in Teams meetings | 1 |
| MT.1038 | MT.1038: Conditional Access policies should not include or exclude deleted groups. See https://maester.dev/docs/tests/MT.1038 | 1 |
| MT.1039 | MT.1039: Ensure MailTips are enabled for end users | 1 |
| MT.1040 | MT.1040: Ensure additional storage providers are restricted in Outlook on the web | 1 |
| MT.1041 | MT.1041: Ensure users installing Outlook add-ins is not allowed | 1 |
| MT.1042 | MT.1042: Restrict dial-in users from bypassing a meeting lobby  | 1 |
| MT.1043 | MT.1043: Ensure Spam confidence level (SCL) is configured in mail transport rules with specific domains | 1 |
| MT.1044 | MT.1044: Ensure modern authentication for Exchange Online is enabled | 1 |
| MT.1045 | MT.1045: Only invited users should be automatically admitted to Teams meetings | 1 |
| MT.1046 | MT.1046: Restrict anonymous users from joining meetings | 1 |
| MT.1047 | MT.1047: Restrict anonymous users from starting Teams meetings | 1 |
| MT.1048 | MT.1048: Limit external participants from having control in a Teams meeting | 1 |
| MT.1049 | MT.1049: Conditional Access policies for User Risk and Sign-in Risk should be configured separately. See https://maester.dev/docs/tests/MT.1049 | 1 |
| MT.1050 | MT.1050: Apps with high-risk permissions having a direct path to Global Admin | 1 |
| MT.1051 | MT.1051: Apps with high-risk permissions having an indirect path to Global Admin | 1 |
| MT.1052 | MT.1052: At least one Conditional Access policy is targeting the Device Code authentication flow. See https://maester.dev/docs/tests/MT.1052 | 1 |
| MT.1053 | MT.1053: Ensure intune device clean-up rule is configured | 1 |
| MT.1054 | MT.1054: Ensure built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant' | 1 |
| MT.1055 | MT.1055: Microsoft 365 Group (and Team) creation should be restricted to approved users. See https://maester.dev/docs/tests/MT.1055 | 1 |
| MT.1056 | MT.1056: Ensure that no person has permanent access to all Azure subscriptions at the root scope | 1 |
| MT.1057 | MT.1057: App registrations should no longer use secrets. See https://maester.dev/docs/tests/MT.1057 | 1 |
| MT.1058 | MT.1058: Exchange application access policies must be configured. See https://maester.dev/docs/tests/MT.1058 | 1 |
| MT.1059 | MT.1059: Defender for Identity health issues | 1 |
| MT.1061 | MT.1061: Device registration MFA control conflicts with Conditional Access policies. See https://maester.dev/docs/tests/MT.1061 | 1 |
| MT.1062 | MT.1062: Ensure Direct Send is set to be rejected | 1 |
| MT.1063 | MT.1063: All App registration owners should have MFA registered | 1 |
| MT.1064 | MT.1064: Ensure that write permissions are required to create new management groups | 1 |
| MT.1065 | MT.1065: Ensure all Recovery Services Vaults have soft delete enabled | 1 |
| MT.1066 | MT.1066: Conditional Access policies should not reference non-existent users, groups, or roles. See https://maester.dev/docs/tests/MT.1066 | 1 |
| MT.1067 | MT.1067: Authentication method policies should not reference non-existent groups. See https://maester.dev/docs/tests/MT.1067 | 1 |
| MT.1068 | MT.1068: Restrict non-admin users from creating tenants. | 1 |
| MT.1069 | MT.1069: Restrict non-admin users from creating security groups. | 1 |
| MT.1070 | MT.1070: Restrict device join to selected users/groups or none. | 1 |
| MT.1071 | MT.1071: At least one Conditional Access policy explicitly includes Azure DevOps. See https://maester.dev/docs/tests/MT.1071 | 1 |
| MT.1072 | MT.1072: Conditional access policies should not use the deprecated Approved Client App grant. See https://maester.dev/docs/tests/MT.1072 | 1 |
| MT.1073 | MT.1073: Soft- and hard-matching of synchronized objects should be blocked. See https://maester.dev/docs/tests/MT.1073 | 1 |
| MT.1074 | MT.1074: Ensure no more then 100 outbound mails per day are send using the .onmicrosoft.com domain | 1 |
| MT.1075 | MT.1075: Require explicit assignment of Third Party Entra Apps. See https://maester.dev/docs/tests/MT.1075 | 1 |
| MT.1076 | MT.1076: MOERA SHOULD NOT be used for sent mail | 1 |
| MT.1077 | MT.1077: App registrations with privileged API permissions should not have owners. See https://maester.dev/docs/tests/MT.1077 | 1 |
| MT.1078 | MT.1078: App registrations with highly privileged directory roles should not have owners. See https://maester.dev/docs/tests/MT.1078 | 1 |
| MT.1079 | MT.1079: Privileged API permissions on service principals should not remain unused. See https://maester.dev/docs/tests/MT.1079 | 1 |
| MT.1080 | MT.1080: Credentials, tokens, or cookies from highly privileged users should not be exposed on vulnerable endpoints. See https://maester.dev/docs/tests/MT.1080 | 1 |
| MT.1081 | MT.1081: Hybrid users should not be assigned Entra ID role assignments. See https://maester.dev/docs/tests/MT.1081 | 1 |
| MT.1083 | MT.1083: Ensure Delicensing Resiliency is enabled | 1 |
| MT.1084 | MT.1084: Microsoft Entra seamless single sign-on should be disabled for all domains in EntraID Connect servers. See https://maester.dev/docs/tests/MT.1084 | 1 |
| MT.1085 | MT.1085: Pending approvals for Critical Asset Management should not be present. See https://maester.dev/docs/tests/MT.1085 | 1 |
| MT.1086 | MT.1086: Devices should not share both critical and non-critical user credentials. See https://maester.dev/docs/tests/MT.1086 | 2 |
| MT.1087 | MT.1087: Devices should not be publicly exposed with remotely exploitable, highly likely to be exploited, high or critical severity CVE's. See https://maester.dev/docs/tests/MT.1087 | 2 |
| MT.1088 | MT.1088: Devices with critical credentials should be protected by TPM. See https://maester.dev/docs/tests/MT.1088 | 2 |
| MT.1089 | MT.1089: Devices with critical credentials should be protected by Credential Guard. See https://maester.dev/docs/tests/MT.1089 | 2 |
| MT.1090 | MT.1090: Global administrator role should not be added as local administrator on the device during Microsoft Entra join | 1 |
| MT.1091 | MT.1091: Registering user should not be added as local administrator on the device during Microsoft Entra join | 1 |
| MT.1092 | MT.1092: Intune APNS certificate should be valid for more than 30 days | 1 |
| MT.1093 | MT.1093: Apple Automated Device Enrollment Tokens should be valid for more than 30 days | 1 |
| MT.1094 | MT.1094: Apple Volume Purchase Program Tokens should be valid for more than 30 days | 1 |
| MT.1095 | MT.1095: Android Enterprise account connection should be healthy | 1 |
| MT.1096 | MT.1096: Ensure at least one Intune Multi Admin Approval policy is configured | 1 |
| MT.1097 | MT.1097: Ensure all Intune Certificate Connectors are healthy and running supported versions | 1 |
| MT.1098 | MT.1098: Mobile Threat Defense Connectors should be healthy | 1 |
| MT.1099 | MT.1099: Windows Diagnostic Data Processing should be enabled | 1 |
| MT.1100 | MT.1100: Intune Diagnostic Settings should include Audit Logs | 1 |
| MT.1101 | MT.1101: Default Branding Profile should be customized | 1 |
| MT.1102 | MT.1102: Windows Feature Update Policy Settings should not reference end of support builds | 1 |
| MT.1103 | MT.1103: Ensure Intune RBAC groups are protected by Restricted Management Administrative Units or Role Assignable groups | 1 |
| MT.1105 | MT.1105: Ensure MDM Authority is set to Intune | 1 |

### Fine-Grained Tags

| Tag | Description | Count |
| --- | --- | --- |
| AdditionalStorageProvidersAvailable | MT.1040: Ensure additional storage providers are restricted in Outlook on the web | 1 |
| App | MT.1002: App management restrictions on applications and service principals is configured and enabled. See https://maester.dev/docs/tests/MT.1002 | 7 |
| Authentication | MT.1067: Authentication method policies should not reference non-existent groups. See https://maester.dev/docs/tests/MT.1067 | 1 |
| Azure | MT.1064: Ensure that write permissions are required to create new management groups | 3 |
| AzureConfig | MT.1064: Ensure that write permissions are required to create new management groups | 3 |
| Backup | MT.1065: Ensure all Recovery Services Vaults have soft delete enabled | 1 |
| CA | MT.1001: At least one Conditional Access policy is configured with device compliance. See https://maester.dev/docs/tests/MT.1001 | 31 |
| CAWhatIf | Conditional Access What If scenarios | 2 |
| Defender | MT.1059: Defender for Identity health issues | 1 |
| DelicensingResiliency | MT.1083: Ensure Delicensing Resiliency is enabled | 1 |
| Deprecated | CISA.MS.EXO.17.2: Microsoft Purview Audit (Premium) logging SHALL be enabled. | 1 |
| Devices | MT.1086: Devices should not share both critical and non-critical user credentials. See https://maester.dev/docs/tests/MT.1086 | 8 |
| DirSync | MT.1073: Soft- and hard-matching of synchronized objects should be blocked. See https://maester.dev/docs/tests/MT.1073 | 1 |
| Entra | MT.1057: App registrations should no longer use secrets. See https://maester.dev/docs/tests/MT.1057 | 22 |
| Entra ID Free | CISA.MS.AAD.5.3: An admin consent workflow SHALL be configured for applications. | 11 |
| Entra ID P1 | CISA.MS.AAD.3.3: If Microsoft Authenticator is enabled, it SHALL be configured to show login context information. | 10 |
| Entra ID P2 | CISA.MS.AAD.7.8: User activation of the Global Administrator role SHALL trigger an alert. | 9 |
| EntraIdConnect | MT.1084: Microsoft Entra seamless single sign-on should be disabled for all domains in EntraID Connect servers. See https://maester.dev/docs/tests/MT.1084 | 1 |
| EntraOps | MT.1077: App registrations with privileged API permissions should not have owners. See https://maester.dev/docs/tests/MT.1077 | 5 |
| Exchange | MT.1043: Ensure Spam confidence level (SCL) is configured in mail transport rules with specific domains | 9 |
| EXO | ORCA.100: Bulk Complaint Level threshold is between 4 and 6. | 67 |
| Exposure Management | MT.1085: Pending approvals for Critical Asset Management should not be present. See https://maester.dev/docs/tests/MT.1085 | 14 |
| Full | MT.1057: App registrations should no longer use secrets. See https://maester.dev/docs/tests/MT.1057 | 6 |
| Governance | MT.1064: Ensure that write permissions are required to create new management groups | 6 |
| Graph | MT.1057: App registrations should no longer use secrets. See https://maester.dev/docs/tests/MT.1057 | 13 |
| Group | MT.1055: Microsoft 365 Group (and Team) creation should be restricted to approved users. See https://maester.dev/docs/tests/MT.1055 | 1 |
| Intune | MT.1092: Intune APNS certificate should be valid for more than 30 days | 15 |
| L1 | CIS.M365.2.1.2: Ensure the Common Attachment Types Filter is enabled (Only Checks Default Policy) | 15 |
| L2 | CIS.M365.1.2.1: Ensure that only organizationally managed/approved public groups exist | 8 |
| License | MT.1022: All users utilizing a P1 license should be licensed. See https://maester.dev/docs/tests/MT.1022 | 2 |
| LongRunning | MT.1057: App registrations should no longer use secrets. See https://maester.dev/docs/tests/MT.1057 | 21 |
| MailTipsExternalRecipientsTipsEnabled | MT.1039: Ensure MailTips are enabled for end users | 1 |
| MDI | MT.1059: Defender for Identity health issues | 1 |
| MeetingPolicy | MT.1037: Only users with Presenter role are allowed to present in Teams meetings | 6 |
| MOERA | MT.1076: MOERA SHOULD NOT be used for sent mail | 1 |
| MyCustomApps | MT.1041: Ensure users installing Outlook add-ins is not allowed | 1 |
| MyMarketplaceApps | MT.1041: Ensure users installing Outlook add-ins is not allowed | 1 |
| MyReadWriteMailboxApps | MT.1041: Ensure users installing Outlook add-ins is not allowed | 1 |
| OAuth2ClientProfileEnabled | MT.1044: Ensure modern authentication for Exchange Online is enabled | 1 |
| PIM | MT.1029: Stale accounts are not assigned to privileged roles. See https://maester.dev/docs/tests/MT.1029 | 4 |
| Preview | MT.1050: Apps with high-risk permissions having a direct path to Global Admin | 2 |
| Privileged | MT.1056: Ensure that no person has permanent access to all Azure subscriptions at the root scope | 14 |
| Recommendation | MT.1024.: . See https://maester.dev/docs/tests/MT.1024 | 1 |
| RejectDirectSend | MT.1062: Ensure Direct Send is set to be rejected | 1 |
| SecureScore | MT.1043: Ensure Spam confidence level (SCL) is configured in mail transport rules with specific domains | 5 |
| Security | CIS.M365.1.2.1: Ensure that only organizationally managed/approved public groups exist | 267 |
| SetScl | MT.1043: Ensure Spam confidence level (SCL) is configured in mail transport rules with specific domains | 1 |
| Teams | MT.1037: Only users with Presenter role are allowed to present in Teams meetings | 6 |
| TransportRule | MT.1043: Ensure Spam confidence level (SCL) is configured in mail transport rules with specific domains | 1 |
| XSPM | MT.1085: Pending approvals for Critical Asset Management should not be present. See https://maester.dev/docs/tests/MT.1085 | 14 |
