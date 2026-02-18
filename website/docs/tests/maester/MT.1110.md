---
title: MT.1110 - No catalog should contain resources without any associated access packages
sidebar_label: MT.1110
description: Checks if catalogs contain orphaned resources that are not used in any access package
slug: /tests/MT.1110
sidebar_class_name: hidden
---

# MT.1110 - No catalog should contain resources without any associated access packages

## Description

This test identifies access package catalogs in Microsoft Entra ID Governance that contain resources (groups, applications, SharePoint sites) not used in any access package. Orphaned resources can indicate:
- Incomplete access package configuration
- Leftover resources from deleted packages
- Configuration drift over time
- Administrative overhead maintaining unused resources

## How to fix

1. Navigate to [Entra ID Governance](https://portal.azure.com/#view/Microsoft_Azure_ELMAdmin)
2. Review the test results to identify which catalogs have orphaned resources
3. For each affected catalog resource:
   - Either add the resource to an access package if it should be governed
   - Or remove the resource from the catalog if it's no longer needed
4. Document decisions for future reference
5. Re-run the test to verify the issue is resolved

## Learn more

- [Manage catalog resources](https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-access-package-resources)
- [Access package catalogs](https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-catalog-create)

%TestResult%
