---
title: MT.1108 - Access packages should not reference inactive or orphaned assignment policies
sidebar_label: MT.1108
description: Checks if access packages reference assignment policies that are disabled, misconfigured, or orphaned
slug: /tests/MT.1108
sidebar_class_name: hidden
---

# MT.1108 - Access packages should not reference inactive or orphaned assignment policies

## Description

This test identifies access packages in Microsoft Entra ID Governance that contain assignment policies which are disabled, misconfigured, or orphaned. Inactive or misconfigured policies can cause:
- Blocked access requests from users
- Broken approval workflows
- Failed provisioning and deprovisioning
- Configuration drift and orphaned policies

## How to fix

1. Navigate to [Entra ID Governance](https://portal.azure.com/#view/Microsoft_Azure_ELMAdmin)
2. Review the test results to identify which access packages have inactive or misconfigured policies
3. For each affected access package:
   - Review the policy state and publish if needed
   - Configure requestor settings with valid scope types
   - Add or update approval stages and approvers
   - Update or remove expired policies
   - Configure required questions properly
4. Remove policies that are no longer needed
5. Re-run the test to verify the issue is resolved

## Learn more

- [Configure access package request settings](https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-access-package-request-policy)
- [Configure approval settings for access packages](https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-access-package-approval-policy)

%TestResult%
