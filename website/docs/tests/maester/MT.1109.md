---
title: MT.1109 - Access package approval workflows must have valid approvers
sidebar_label: MT.1109
description: Checks if approval workflows reference valid, active approvers that are not deleted or disabled
slug: /tests/MT.1109
sidebar_class_name: hidden
---

# MT.1109 - Access package approval workflows must have valid approvers

## Description

This test identifies access package assignment policies in Microsoft Entra ID Governance that have approval workflows referencing invalid approvers. Invalid approvers can cause:
- Blocked access requests when approvers don't exist
- Workflow timeouts waiting for non-existent approvers
- Failed approval stages causing request failures
- Manual intervention required for urgent access

## How to fix

1. Navigate to [Entra ID Governance](https://portal.azure.com/#view/Microsoft_Azure_ELMAdmin)
2. Review the test results to identify which access packages have invalid approvers
3. For each affected access package policy:
   - Remove references to deleted or disabled users
   - Add valid replacement approvers
   - Ensure approval groups exist and have active members
   - Add members to empty approval groups
   - Consider using groups instead of individual users for resilience
4. Test the approval workflow to ensure it functions correctly
5. Re-run the test to verify the issue is resolved

## Learn more

- [Configure approval settings for access packages](https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-access-package-approval-policy)
- [Approval workflow settings](https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-access-package-request-policy)

%TestResult%
