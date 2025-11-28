---
title: MT.1085 - Pending approvals for Critical Asset Management should not be present
description: This check is using a KQL query to identify assets with low classification confidence which require manual approval by a security administrator.
slug: /tests/MT.1085
sidebar_class_name: hidden
---

## Description
Executes a KQL query on `ExposureGraphNodes` in Advanced Hunting to identify assets with a `criticalityConfidenceLow` value, which indicates they do not meet the automatic classification threshold.

_Side Note: Approved assets will be reflected in the table within 24 hours. Please account for this delay when reviewing updated assets in the Maester test results._

## Why This Matters

Microsoft provides an approval step for assets that do not meet the automatic classification threshold. Assets with a lower classification confidence score must be approved by a security administrator.
Stale pending approvals can lead to limited visibility in Microsoft Defender XDR and potential security risks if critical assets are not properly identified.

Therefore, you should regularly [review critical assets](https://learn.microsoft.com/en-us/security-exposure-management/classify-critical-assets#review-critical-assets) to ensure the correct classification has been applied to your assets.

#### Remediation action

On the [Critical asset management page](https://security.microsoft.com/securitysettings/defender/critical_asset_management), review the asset classification named in the Maester test results. Review the pending approvals and verify the correct classification of the listed assets.

More details are available in the Microsoft Learn article: "[Add assets to predefined classifications](https://learn.microsoft.com/en-us/security-exposure-management/classify-critical-assets#add-assets-to-predefined-classifications)".

#### Related links

- [Review and classify critical assets - Microsoft Learn](https://learn.microsoft.com/en-us/security-exposure-management/classify-critical-assets)
- [Predefined classifications - Microsoft Learn](https://learn.microsoft.com/en-us/security-exposure-management/predefined-classification-rules-and-levels)
