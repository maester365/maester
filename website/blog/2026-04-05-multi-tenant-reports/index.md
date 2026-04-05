---
title: Multi-Tenant Reports are here!
description: Monitor multiple Microsoft 365 tenants in a single Maester report with a tenant selector
slug: multi-tenant-reports
authors: sebastian
tags: [feature, multi-tenant]
hide_table_of_contents: false
image: ./img/multi-tenant-header.png
date: 2026-04-05
---

We are excited to announce that Maester now supports multi-tenant reports! Run your security tests across multiple tenants and view the results in a single report. 🚀

<!-- truncate -->

![Multi-tenant report overview](./img/multi-tenant-header.png)

If you're like me and manage multiple Azure tenants that span across national clouds, you probably know the pain of having to open separate reports for each one. Not anymore!

### Quick Stats

- 🚀 Run Maester tests across multiple tenants in a single pipeline run
- 🔥 Switch between tenants in one report using the sidebar
- 🤝 Full dashboard per tenant, charts, filters, everything
- 🔐 Each tenant uses its own service connection with read-only permissions
- ⚙️ Tenant-specific `maester-config.{TenantId}.json` support

Single tenant reports continue to work exactly as before. The tenant selector only appears when there are multiple tenants in the report.

### Get Started

Check out the documentation to get your multi-tenant monitoring up and running:

- Documentation: [Multi-Tenant Overview](/docs/next/multi-tenant/overview)
- Documentation: [Merging Results](/docs/next/multi-tenant/merging-results)
- Documentation: [Tenant-specific Configuration](/docs/next/multi-tenant/configuration)
- Documentation: [Azure DevOps Pipeline](/docs/next/multi-tenant/azure-devops-pipeline)

## Contributor

- [Sebastian Claesson](/blog/authors/sebastian)
