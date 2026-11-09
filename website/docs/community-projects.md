---
title: Community projects
description: Open-source projects and commercial products that build on Maester, from deployment templates to managed services.
---

Maester is open source, so other people build on it. This page lists the projects and products we know of that run Maester or use its results, so you can find one that fits how you work.

We don't review or endorse these projects, and we haven't tested them ourselves. Check what each one asks for, such as permissions, data storage and pricing, before you use it with your tenant. To add your project or correct an entry, edit this page with the link at the bottom and open a pull request.

## Open source

### Run Maester on a schedule

| Project | By | What it does |
| --- | --- | --- |
| [azd-maester](https://github.com/nathanmcnulty/azd-maester) | Nathan McNulty | Azure Developer CLI templates that run Maester with managed identities on [Azure Automation](https://github.com/nathanmcnulty/azd-maester-azureautomation), [Azure Functions](https://github.com/nathanmcnulty/azd-maester-functionapp), [Azure Container Apps jobs](https://github.com/nathanmcnulty/azd-maester-containerappjob) or [Azure DevOps](https://github.com/nathanmcnulty/azd-maester-azuredevops). |
| [DriftMaester](https://github.com/jflieben/DriftMaester) | Jos Lieben | Deploys Maester to Azure Automation with one command. It runs on a schedule, keeps the history in Blob Storage, flags drift and regressions, and emails the report. |
| [Kickstarter: Maester & UTCM Dashboard](https://github.com/fortytwoservices/kickstarter-maester-and-utcm) | Fortytwo | An Azure Web App that runs Maester daily and lets you browse the reports by date. It adds drift detection through Unified Tenant Configuration Management (UTCM), baselines, webhooks and a remediation board. |
| [Maester-O365](https://github.com/adrian207/Maester-O365) | Adrian Johnson | A GitHub template that runs Maester every day with workload identity federation, so no secret is stored. One script sets up the app and secrets. |
| [terraform-azure-maester-deployment](https://github.com/hlokensgard/terraform-azure-maester-deployment) | [hlokensgard](https://github.com/hlokensgard) | A Terraform module that deploys Maester to Azure Automation, with an optional web app to view the report. |

### Assessments that include Maester

| Project | By | What it does |
| --- | --- | --- |
| [GxAssessMS](https://github.com/Guardantix/gxassessms) | Guardantix | Runs ScubaGear, Maester, Monkey365, Prowler and other tools from one config file. It merges their overlapping findings and writes one Word report. |
| [M365Assessment](https://github.com/patramsden/M365Assessment) | [patramsden](https://github.com/patramsden) | Runs Maester, then its own Conditional Access, Entra ID, Copilot data security and Purview reviews, and writes an HTML dashboard and a Word or PDF report. |

### Tests and packs

[Maester Packs](https://packs.maester.cloud) lists the community packs you can install with `Install-MtPack`. Collections of custom tests include:

- [Custom-Maester-Tests](https://github.com/DevClate/Custom-Maester-Tests) by Clayton (DevClate)
- [maester-copilot-tests](https://github.com/LukeEvansTech/maester-copilot-tests), Microsoft 365 Copilot checks by Luke Evans
- [entra-ca-templates](https://github.com/LukeEvansTech/entra-ca-templates), Conditional Access policies as code checked with Maester, by Luke Evans

## Commercial products and services

| Product | By | What it is | Price |
| --- | --- | --- | --- |
| [Maester Cloud](https://maester.cloud) | Jozra, from Maester's creator | Runs Maester and Microsoft's Zero Trust Assessment in your own Azure subscription. It keeps the run history for every tenant, tracks findings and drift, and sends alerts. Also on the [Microsoft Marketplace](https://marketplace.microsoft.com/en-us/product/jozra.maester-cloud). | From $99 a month ([pricing](https://maester.cloud/pricing)) |
| [Maester my Microsoft 365](https://marketplace.microsoft.com/en-us/product/fortytwoio.maester) | Fortytwo | An Azure application on the Microsoft Marketplace that deploys Maester and UTCM monitoring into your own tenant. It includes run history, a remediation board and configuration baselines. | Free, according to [Fortytwo](https://fortytwo.io/marketplace-products/maester-my-microsoft-365/) |
| [Coldbyte Security](https://marketplace.microsoft.com/en-us/product/coldbyteas1788469511939.coldbyte-security) | Coldbyte | Runs Maester and the Zero Trust Assessment every day in a deployment in your Azure subscription. It explains findings and security events in Teams and, on the Full plan, applies fixes you approve. | From $5 per user a month, plus Azure consumption |
| [Mobula](https://mobula.cloud) | Mobula Cloud | A platform for managed service providers that scans customers' Azure, Microsoft 365, Entra ID, GitHub and Fabric. It shows Maester results and what changed since the last scan, including in a [Microsoft 365 Copilot connector](https://marketplace.microsoft.com/en-us/product/WA200012816). | Mobula subscription |
| [TestimoX](https://testimox.com/maester/) | Evotec | An Active Directory assessment platform. It runs its assessment once and passes signed results to Maester, which shows them in the Maester report. | The Maester integration is free; [paid tiers](https://testimox.com/pricing/) add more |
| [Security Guardian for Microsoft 365](https://marketplace.microsoft.com/en-us/product/sentineltechnologiesinc.sti-maester-managed) | Sentinel Technologies | A managed service: monthly security posture reports against CISA SCuBA and CIS guidance, and monthly calls with engineers who review the findings. | From $18,000 a year |
