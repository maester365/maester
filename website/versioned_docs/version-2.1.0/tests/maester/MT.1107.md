---
title: MT.1107 - Access packages and catalogs should not reference deleted groups
sidebar_label: MT.1107
description: Checks if Entra ID Governance access packages or catalogs reference deleted groups
slug: /tests/MT.1107
sidebar_class_name: hidden
---

# MT.1107 - Access packages and catalogs should not reference deleted groups

## Description

This test identifies access packages and catalogs in Microsoft Entra ID Governance that reference Entra ID groups which have been deleted. Deleted group references can cause:
- Unexpected access provisioning failures
- Configuration inconsistencies
- Approval workflow issues
- Compliance and audit concerns

## How to fix

1. Navigate to [Entra ID Governance](https://portal.azure.com/#view/Microsoft_Azure_ELMAdmin)
2. Review the test results to identify which access packages/catalogs reference deleted groups
3. For each affected resource:
   - Either restore the deleted group from the recycle bin
   - Or remove the group reference from the access package/catalog
4. Re-run the test to verify the issue is resolved

## Learn more

- [Manage access packages in Entra ID Governance](https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-access-package-create)
- [Access package catalogs](https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-catalog-create)

%TestResult%
