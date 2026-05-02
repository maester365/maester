---
title: MT.1106 - Catalog resources must have valid roles (no stale / removed app roles or SPNs)
sidebar_label: MT.1106
description: Checks if catalog resources reference valid service principals, app roles, and accessible SharePoint sites
slug: /tests/MT.1106
sidebar_class_name: hidden
---

# MT.1106 - Catalog resources must have valid roles (no stale / removed app roles or SPNs)

## Description

This test identifies catalog resources in Microsoft Entra ID Governance that reference stale or invalid roles, deleted service principals, or non-existent SharePoint sites. Stale resources can cause:
- Access provisioning failures when users request access
- Broken approval workflows
- User assignment errors preventing access
- Manual intervention required to fix failed provisioning

## How to fix

1. Navigate to [Entra ID Governance](https://portal.azure.com/#view/Microsoft_Azure_ELMAdmin)
2. Review the test results to identify which catalog resources have stale roles or deleted SPNs
3. For each affected resource:
   - For deleted applications: Remove from catalog or restore the application
   - For stale app roles: Update access packages to remove invalid roles or contact app owner to restore roles
   - For SharePoint sites: Remove from catalog, fix the URL, or restore deleted sites
4. Update access packages that referenced the stale resources
5. Re-run the test to verify the issue is resolved

## Learn more

- [Manage catalog resources](https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-access-package-resources)
- [Service principal app roles](https://learn.microsoft.com/graph/api/resources/approle)
- [SharePoint site resource type](https://learn.microsoft.com/graph/api/resources/site)

%TestResult%
