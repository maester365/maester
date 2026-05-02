---
title: "What's new in Maester 2.1.0"
description: Azure DevOps tests, Copilot Studio agent checks, Defender for Endpoint coverage, multi-tenant reporting, CIS updates, and more.
slug: whats-new-since-maester-2-0
authors: [maesterteam]
tags: [maester, release, security, entra, m365, azuredevops, defender]
hide_table_of_contents: false
date: 2026-05-01
---

When we launched [Maester 2.0](/blog/maester-2-0), it was our biggest release yet. Since then the project has kept moving: more than 540 commits, 1,900 files touched, and the published test documentation has grown from 128 to 168 tests.

This release brings Maester into more of the places security teams live every day: Azure DevOps, Microsoft Defender for Endpoint, Copilot Studio, entitlement management, multi-tenant operations, and the report experience itself.

<!-- truncate -->

## Highlights

- **Azure DevOps security tests**: 37 optional tests covering OAuth, SSH, audit logs, public projects, PAT policy, pipeline hardening, Advanced Security, and privileged Azure DevOps roles.
- **Copilot Studio and AI agent tests**: 10 new checks for risky agent sharing, authentication, HTTP configuration, email exfiltration paths, author authentication, MCP tools, dormant agents, hard-coded credentials, custom instructions, and orphaned ownership.
- **Microsoft Defender for Endpoint checks**: 24 antivirus and endpoint security tests covering cloud protection, network protection, real-time monitoring, PUA protection, signature updates, sample submission, scan behavior, and local admin merge.
- **Multi-tenant reporting**: run Maester across multiple tenants and merge the results into a single report with a tenant selector.
- **CIS Microsoft 365 Foundations Benchmark 6.0.1 updates**: CIS coverage and documentation have been refreshed to align with the newer benchmark.
- **New Entra ID and entitlement management checks**: new tests catch stale access package references, invalid approvers, orphaned resources, and hybrid identity risks.
- **Better report and operations experience**: deep links to individual test results, improved markdown severity output, cleaner skipped/investigate counts, and more resilient build and release automation.

## Azure DevOps tests

Maester now includes an optional Azure DevOps security test suite. The tests are discovered automatically and run when you connect to Azure DevOps using the community [ADOPS PowerShell module](https://www.powershellgallery.com/packages/ADOPS).

```powershell
Install-Module Maester, ADOPS
Connect-ADOPS -Organization <your-organization>
Invoke-Maester
```

The suite includes 37 tests across organization, repository, pipeline, artifact, and PAT controls. It covers high-impact settings such as third-party OAuth app access, SSH authentication, auditing, public projects, external guests, job authorization scope, queue-time variables, classic pipeline creation, marketplace tasks, Shell Task argument validation, TFVC creation, Project Collection Administrators, leaked PAT auto-revocation, and full-scoped PAT restrictions.

This work was led by [Sebastian Claesson](/blog/authors/sebastian), with follow-up fixes and documentation improvements from the wider community.

## Copilot Studio and AI agent security

AI agents are quickly becoming part of the Microsoft 365 attack surface, so Maester now includes checks for Copilot Studio agents.

The new `MT.1113` to `MT.1122` tests look for:

- Broadly shared agents
- Agents without user authentication
- Risky HTTP configurations
- Email sending with AI-controlled inputs
- Dormant published agents
- Author or maker authentication on connections
- Hard-coded credentials in topics
- MCP server tools that need review
- Missing custom instructions for generative orchestration
- Orphaned ownership

These checks use Dataverse data for the Copilot Studio environment configured in `maester-config.json`, helping teams review agent risk alongside their existing Entra, Exchange, Teams, and Microsoft 365 security tests.

Special thanks to [Truls](https://github.com/lnfernux) for adding Copilot Studio support to Maester, with follow-up cleanup and polish from Sam and Merill.

## Defender for Endpoint coverage

This release adds a large Microsoft Defender for Endpoint test set, covering practical endpoint security baseline checks such as archive scanning, behavior monitoring, cloud protection, email and script scanning, real-time monitoring, network protection, PUA protection, signature update cadence, sample submission, and more.

The Defender work also adds reusable helper functions for reading MDE configuration and policy state, making it easier to build more endpoint checks in future releases.

Special thanks to [Boris Drogja](https://github.com/bdrogja) for adding the MDE support, with follow-up test cleanup from [Sam Erde](/blog/authors/samerde).

## Multi-tenant reports

For consultants, managed service providers, partners, and organizations with multiple tenants, Maester can now merge results from multiple tenant runs into a single report.

```powershell
Merge-MtMaesterResult -Path ./results/ | Get-MtHtmlReport | Out-File ./report.html
```

The report automatically detects multi-tenant results and shows a tenant selector in the sidebar. Each tenant keeps its own dashboard, charts, filters, config view, and results. You can also use tenant-specific configuration files such as `maester-config.{TenantId}.json` for different emergency access accounts and severity overrides per tenant.

Read more in the [multi-tenant reports announcement](/blog/multi-tenant-reports).

Special thanks to [Sebastian Claesson](/blog/authors/sebastian) for building the multi-tenant report experience.

## More Entra ID coverage

Maester now has additional checks for entitlement management and hybrid identity risks, including:

- `MT.1106`: Catalog resources must have valid roles
- `MT.1107`: Access packages and catalogs should not reference deleted groups
- `MT.1108`: Access packages should not reference inactive or orphaned assignment policies
- `MT.1109`: Access package approval workflows must have valid approvers
- `MT.1110`: Catalogs should not contain resources without associated access packages
- `MT.1147`: Do not sync `krbtgt_AzureAD` to Entra ID

These are the kinds of configuration issues that are easy to miss until access reviews, entitlement cleanup, or hybrid identity incidents force the conversation. Maester can now flag them continuously.

Special thanks to [Nico Wyss](https://github.com/nicowyss) for the entitlement management tests and [Fabian Bader](/blog/authors/fabian) for the `krbtgt_AzureAD` hybrid identity check.

## CIS, tags, and test inventory

The CIS Microsoft 365 Foundations Benchmark content has been refreshed for v6.0.1, with updated descriptions, coverage tables, and test mappings.

We also added generated tag inventory support using `Get-MtTestInventory`, building on the [Maester tags improvements](/blog/whats-new-with-maester-tags). This gives contributors a clearer view of the tags already in use and helps users select tests by suite, product area, practice, or capability without guessing.

Special thanks to Benjamin Metz for adding the CIS tests, [Morten Mynster](https://github.com/Mynster9361) for the CIS v6.0.1 refresh, and [Sam Erde](/blog/authors/samerde) for the tag inventory and tag documentation automation.

## Report and platform improvements

The report keeps getting sharper. Since 2.0 we have added direct links to individual test results, improved markdown output with severity details, fixed long organization names in the sidebar, improved skipped and investigate counts in alerts, and cleaned up several report build and dependency issues.

Behind the scenes, the project also gained CodeQL scanning, PR-triggered website build validation, dependency review, safer workflow permissions, issue forms, automatic Entra role definition update automation, and a consolidated module build script.

These are not always the flashiest release notes, but they make Maester easier to maintain, easier to trust, and easier for contributors to extend.

Special thanks to [Sam Erde](/blog/authors/samerde) for report deep links, build automation, CodeQL and workflow hardening, and release plumbing; and to Morten Mynster for report template and UI improvements.

## Contributors

Maester continues to be a community project, and this release shows it.

Special callouts for this release:

- [Sam Erde](/blog/authors/samerde) for report deep links, tag documentation automation, build automation, CodeQL and workflow hardening, docs, and release quality.
- [Sebastian Claesson](/blog/authors/sebastian) for the Azure DevOps test suite and multi-tenant reporting work.
- [Boris Drogja](https://github.com/bdrogja) for adding Microsoft Defender for Endpoint support.
- [Truls](https://github.com/lnfernux) for adding Copilot Studio support.
- [Nico Wyss](https://github.com/nicowyss) for the entitlement management tests.
- [Fabian Bader](/blog/authors/fabian) for the `krbtgt_AzureAD` hybrid identity check.
- Benjamin Metz for adding the CIS tests.
- [Thomas Naunheim](/blog/authors/thomas) for continued review, test coverage, and project improvements.
- [Morten Mynster](https://github.com/Mynster9361) for major contributions across tests, CIS updates, and report/template improvements.
- Frode Flaten, Brian Reid, Anas, Ricardo Mestre, Matt Cave, Brian Veldman, and everyone who opened issues, reviewed PRs, tested preview builds, or fixed docs.

And thank you to everyone using Maester in real tenants. The feedback, edge cases, and "this failed in my environment" reports are what turn good ideas into reliable security checks.

## Get the update

Update Maester and your tests:

```powershell
Update-Module Maester
Update-MaesterTests
```

Then explore the new areas:

```powershell
# Azure DevOps tests
Connect-ADOPS -Organization <your-organization>
Invoke-Maester

# Copilot Studio / AI agent tests
Connect-Maester -Service Dataverse
Invoke-Maester -Tag AIAgent

# Defender for Endpoint tests
Invoke-Maester -Tag Defender

# Multi-tenant report
Merge-MtMaesterResult -Path ./results/ | Get-MtHtmlReport | Out-File ./report.html
```

This release is a big step toward making Maester the continuous security validation layer for Microsoft 365, Entra, Defender, Azure DevOps, and the new AI surfaces that are arriving fast.
