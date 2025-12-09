---
title: MT.1080 - Credentials, tokens, or cookies from highly privileged users should not be exposed on vulnerable endpoints
description: Checks for CLI secrets, user cookies, and sensitive token artifacts of privileged users that are available from endpoints with a high risk or exposure score.
slug: /tests/MT.1080
sidebar_class_name: hidden
---

# Credentials, tokens, or cookies from highly privileged users should not be exposed on vulnerable endpoints

## Prerequisites
Assignments to Microsoft Entra will be analyzed by using the `IdentityInfo` in Microsoft Defender XDR.
As documented in [Microsoft Learn](https://learn.microsoft.com/en-us/defender-xdr/advanced-hunting-identityinfo-table), the details of `PrivilegedEntraPimRoles` are only available for tenants with Microsoft Defender for Identity.
Therefore, the checks are only available for tenants with onboarded MDI instance.

In addition, the table `OAuthAppInfo` will be used to get details about applications including unused permissions and permission scope / criticiality. This table is populated by app governance records from Microsoft Defender for Cloud Apps.
You need to turn on app governance to use this check. To turn on app governance, follow the steps in [Turn on app governance](https://learn.microsoft.com/en-us/defender-cloud-apps/app-governance-get-started).

## Description

Exposure Management identifies credentials that are exposed on endpoints by using various signals and telemetry. For example, user cookies are identified by [Smart Analysis of Browser Artifacts](https://techcommunity.microsoft.com/blog/microsoft-security-blog/bridging-the-on-premises-to-cloud-security-gap-cloud-credentials-detection/4211794). The analysis runs periodically using Microsoft Defender for Endpoint. Currently, user cookies, primary refresh tokens, and Azure CLI secrets are supported. These identified secrets are available in the `ExposureGraphEdges` table of Microsoft Defender XDR. This check filters for exposed artifacts on endpoints with a high machine risk score or high [exposure score](https://learn.microsoft.com/en-us/defender-vulnerability-management/tvm-exposure-score) as determined by Defender for Endpoint.

In addition, only authentication artifacts from users with eligible or permanent Entra ID roles on the Control Plane and Management Plane (classified by the community project [EntraOps](https://github.com/Cloud-Architekt/AzurePrivilegedIAM)), or any user with a criticality level lower than Tier 1 (defined in [Critical Asset Management](https://learn.microsoft.com/en-us/security-exposure-management/classify-critical-assets)), will be in scope for this check.

Exfiltration of authentication artifacts on vulnerable device poses a significant security risk. Attackers who gain access to these credentials (e.g., by infostealer) can impersonate privileged users, bypass Conditional Access, and access sensitive the assigned sensitive roles. Protecting endpoints, especially used by privileged users, is essential to prevent unauthorized access and reduce attack surface.

## How to fix
Review the details of risk and exposure score on the related [device page from the Device Inventory](https://learn.microsoft.com/en-us/defender-endpoint/machines-view-overview#device-inventory-overview) in the Microsoft Defender XDR portal to improve the device's security posture.