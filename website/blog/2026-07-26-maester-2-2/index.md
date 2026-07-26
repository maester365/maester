---
title: "Introducing Maester 2.2 🚀"
description: Deep Active Directory coverage, Global Secure Access and Microsoft Purview checks, GitHub and SharePoint security tests, contributor credits, and a sharper report experience.
slug: maester-2-2
authors: [maesterteam]
tags: [maester, release, security, entra, m365, activedirectory, purview, github]
hide_table_of_contents: false
date: 2026-07-26
---

Maester 2.2 is here, with our biggest expansion of security coverage so far.

Since Maester 2.1.0, the community has contributed 252 commits and 311 new public `Test-*` functions. The release reaches from on-premises Active Directory to Microsoft Entra Global Secure Access, Microsoft Purview, Intune, SharePoint Online, and GitHub.

<!-- truncate -->

## Highlights

- **269 Active Directory checks** across identity, policy, infrastructure, DNS, trusts, replication, and access control
- **9 Global Secure Access checks** for Private Access, forwarding profiles, Compliant Network, connector groups, and Internet Access
- **5 Microsoft Purview checks for AI data security** covering audit, sensitivity labels, Insider Risk Management, DLP, and retention
- **12 new SharePoint Online checks** across the CIS and CISA baselines, with cross-platform PnP.PowerShell support
- **5 CIS GitHub organization controls** and first-class GitHub connectivity
- **4 Intune endpoint security checks** for LAPS, attack surface reduction, App Control for Business, and Managed Installer
- **New Entra ID checks** for agent risk, directory synchronization safeguards, Conditional Access coverage, legacy MSOnline, and privileged first-party apps
- **Better reports and release quality**, including markdown summaries, duration and severity ordering, quieter filtered results, version tracking, and stronger smoke-test automation
- **Contributor credits throughout maester.dev**, with authorship derived from Git history and displayed on generated test documentation

## Deep Active Directory coverage

Maester can now assess on-premises Active Directory alongside Microsoft 365 and Microsoft Entra.

The release adds 269 opt-in AD checks across 19 areas, including:

- Users, groups, computers, and service principal names
- Password policy and fine-grained password policy
- Domain, forest, domain controller, site, subnet, and replication health
- DNS, trusts, schema, and directory configuration
- Group Policy inventory and state
- DACL and privileged access analysis

AD testing is deliberately opt-in. `Connect-Maester -Service All` does not connect to Active Directory, and AD tests remain excluded until an explicit connection succeeds:

```powershell
Connect-Maester -Service ActiveDirectory
Invoke-Maester -Path "./ad" -SkipGraphConnect -NonInteractive
```

The first release of this coverage is a preview. We would especially value feedback on result quality, performance in larger environments, and checks that need clearer thresholds or remediation guidance. Please [open an issue](https://github.com/maester365/maester/issues/new/choose) or join the conversation in the [Maester Discord](https://discord.maester.dev/).

Special thanks to [Mike Soule](https://github.com/soulemike) for building and validating this substantial new area of Maester.

## Global Secure Access

Nine preview checks now cover Microsoft Entra Global Secure Access and Private Access:

| Test | What it checks |
| --- | --- |
| `MT.1187` | The Microsoft 365 traffic forwarding profile is enabled |
| `MT.1188` | Private Access apps are covered by managed-device Conditional Access |
| `MT.1189` | Traffic-forwarding-profile assignment groups are not nested |
| `MT.1190` | Private Access apps do not use the Default connector group |
| `MT.1191` | Break-glass accounts are excluded from Compliant Network policies |
| `MT.1192` | Private Access application assignment groups are not nested |
| `MT.1193` | Private Access segments avoid broad or risky destinations |
| `MT.1194` | The baseline security profile enforces threat intelligence |
| `MT.1195` | Quick Access is not disrupted by sign-in-frequency controls |

These checks are read-only and skip gracefully when the relevant capability is not configured. They also add the read-only `NetworkAccess.Read.All` permission to the default Graph scope set.

Special thanks to [Christopher Brumm](https://github.com/crmhh) for developing the checks, validating them against a live tenant, and reconciling them with the Microsoft Zero Trust Assessment to avoid duplicate coverage.

## Microsoft Purview and AI data security

The new `MT.1172` to `MT.1176` checks help organizations prepare their data security controls for Microsoft 365 Copilot and other AI workloads:

- Unified audit log ingestion is enabled
- Sensitivity labels for files are published
- An Insider Risk Management policy covers risky AI usage
- A DLP policy covers the Microsoft 365 Copilot location
- A retention policy covers Microsoft Copilot interactions

Together, these checks cover the audit, classification, investigation, data loss prevention, and retention foundations that help keep AI adoption governable.

Special thanks to [Ofir Gavish](https://github.com/OfirGavish) for adding the Microsoft Purview coverage.

## SharePoint Online: CIS, CISA, and PnP.PowerShell

Maester now has cross-platform SharePoint Online connectivity through PnP.PowerShell.

This release adds six CIS Microsoft 365 Foundations Benchmark checks for SharePoint sharing and download controls, plus six new CISA SCuBA checks. The two existing CISA SharePoint checks were also moved to the same connection path, completing all eight CISA SharePoint baseline controls.

The coverage includes:

- Default sharing scope and permission
- Anyone-link expiration and permissions
- OneDrive external sharing
- Verification-code reauthentication
- Guest sharing and B2B integration
- Protection against downloading malicious files

Special thanks to [Morten Mynster](https://github.com/Mynster9361), [Henrik Piecha](https://github.com/HenrikPiecha), [Simon Albers](https://github.com/DataAndGoliath), and [PulpyJuice](https://github.com/PulpyJuice) for the SharePoint implementations and follow-up work.

## GitHub security and easier GitHub Actions setup

Maester 2.2 adds first-class GitHub connectivity and five CIS GitHub organization controls:

- Strict base repository permissions
- Restricted repository creation
- Restricted repository deletion
- Restricted team creation
- Restricted issue deletion

You can connect Maester to a GitHub organization and run the controls alongside the rest of your security tests:

```powershell
Connect-Maester -Service GitHub
Invoke-Maester -Tag "CIS GH"
```

Setting up Maester in GitHub Actions is also much simpler. From a `maester-tests` repository, Maester can detect the Git remote, create the federated credential, and set the required Actions secrets:

```powershell
Connect-Maester -Service Azure
New-MtMaesterApp -GitHubActions -SetGitHubSecrets
```

Special thanks to [Travis McDade](https://github.com/thetechgy) for the GitHub connection and CIS controls, and [Loïc Michel](https://github.com/kayasax) for the zero-configuration GitHub Actions setup.

## More Intune and Entra ID checks

Four new Intune checks cover endpoint controls that are central to a modern Windows security baseline:

- `MT.1177`: Windows LAPS configuration
- `MT.1178`: Attack Surface Reduction rules
- `MT.1179`: App Control for Business
- `MT.1180`: Managed Installer

Maester also adds checks for high agent-risk sign-ins, the protected `onPremisesObjectIdentifier` update path, Conditional Access policies with no target resources, legacy MSOnline PowerShell authentication, high-privilege first-party Entra applications without explicit assignment, DMARC on verified domains, and BitLocker recovery-key restrictions.

Special thanks to [Ofir Gavish](https://github.com/OfirGavish), [ExeqZ](https://github.com/ExeqZ), [Jan Bakker](https://github.com/BakkerJan), and [Matthias](https://github.com/blindzero) for this new coverage.

## Reports, automation, and contributor credits

The report experience continues to improve:

- Markdown summary generation for pipelines and pull requests
- Per-test duration in the HTML report
- Critical findings ordered ahead of lower-severity results
- Filtered `NotRun` results hidden by default, while remaining available in the status filter
- Less warning noise for intentionally filtered tests
- More reliable license-aware skipping and result conversion

The project also now tracks module and configuration versions, validates the Maester action across platforms, runs quick and full smoke tests against a demo tenant, and avoids unnecessary tenant runs for documentation-only changes.

Most importantly, maester.dev now credits the people behind the tests. Authorship is derived from Git history, enriched with contributor profiles, and shown on generated test pages and the new [contributors page](/contributors).

## Thank you to every contributor

Maester 2.2 includes human-authored or human-co-authored work from 26 people in the `2.1.0` to 2.2 release range:

- [Artem Borodai](https://github.com/artemop) — made role lookup initialization resilient.
- [Brian Reid](https://github.com/brianreidc7) — improved managed-domain and MFA policy checks.
- [Christopher Brumm](https://github.com/crmhh) — added the nine Global Secure Access checks.
- [Christopher Edwards](https://github.com/Korthal-Maiyn) — added license-aware skips for Intune and Defender for Office 365 tests.
- [ExeqZ](https://github.com/ExeqZ) — added the high agent-risk Conditional Access check.
- [Henrik Piecha](https://github.com/HenrikPiecha) — originated and co-authored SharePoint Online CIS coverage.
- [Jan Bakker](https://github.com/BakkerJan) — added five new Entra and CIS checks and strengthened Conditional Access error handling.
- [Jean-Philippe George](https://github.com/JeanPhilippeGeorge) — improved license-aware results, parameter handling, and documentation.
- [Jon Gross](https://github.com/jongross4) — fixed non-terminating error handling in a tenant edge case.
- [Jon Hope](https://github.com/Jhope188) — fixed ORCA and Conditional Access role-lookup edge cases.
- [Loïc Michel](https://github.com/kayasax) — added zero-configuration GitHub Actions and OIDC setup.
- [Massimo Mazzariol](https://github.com/massimomazzariol) — documented Microsoft Graph scopes in connection results.
- [Matthias](https://github.com/blindzero) — added DMARC coverage and fixed verified-domain handling.
- [Merill Fernando](https://github.com/merill) — integrated the release, report, website, smoke-test, and automation improvements.
- [Mike Soule](https://github.com/soulemike) — added and validated the 269 Active Directory checks.
- [Morten Mynster](https://github.com/Mynster9361) — added SharePoint Online CIS and CISA coverage, PnP.PowerShell support, and report and build fixes.
- [Ofir Gavish](https://github.com/OfirGavish) — added the Microsoft Purview and Intune endpoint security checks.
- [PulpyJuice](https://github.com/PulpyJuice) — co-authored the CISA SharePoint Online follow-up.
- [Sam Erde](https://github.com/SamErde) — strengthened release automation, code scanning, generated documentation, version tracking, and report quality.
- [seick](https://github.com/seick) — fixed workload identity policy handling and completed permission documentation.
- [Simon Albers](https://github.com/DataAndGoliath) — contributed the SharePoint Online implementation adopted in this release.
- [Stephan van Rooij](https://github.com/svrooij) — added markdown summary report generation.
- [Thomas Naunheim](https://github.com/Cloud-Architekt) — improved delegated-permission support and error handling.
- [Thomas S. Schmidt](https://github.com/thomas-s-schmidt) — fixed Defender for Identity health-response handling.
- [Travis McDade](https://github.com/thetechgy) — added GitHub connectivity and the CIS GitHub organization controls.
- [Truls Thorstad Dahlsveen](https://github.com/lnfernux) — expanded permissions documentation.

Thank you as well to everyone who reviewed a pull request, reported an issue, tested a preview build, improved documentation, or shared tenant-specific edge cases. That work is what turns a large set of checks into a dependable security testing framework.

## Get Maester 2.2

Update the module and your test collection:

```powershell
Update-Module Maester
Update-MaesterTests
```

Then explore the new areas:

```powershell
# Active Directory (explicit opt-in)
Connect-Maester -Service ActiveDirectory
Invoke-Maester -Path "./ad" -SkipGraphConnect -NonInteractive

# Global Secure Access preview checks
Invoke-Maester -Tag "MT.1187", "MT.1188", "MT.1189", "MT.1190", "MT.1191", "MT.1192", "MT.1193", "MT.1194", "MT.1195"

# Microsoft Purview and AI data security
Invoke-Maester -Tag "MT.1172", "MT.1173", "MT.1174", "MT.1175", "MT.1176"

# Intune endpoint security
Invoke-Maester -Tag "MT.1177", "MT.1178", "MT.1179", "MT.1180"

# CIS GitHub controls
Connect-Maester -Service GitHub
Invoke-Maester -Tag "CIS GH"
```

Maester 2.2 gives security teams a broader view of the identity and collaboration estate—from Active Directory and endpoint controls to AI data security, cloud access, and developer platforms—while making the people behind that coverage visible.
