---
title: "Introducing Maester 2.2 🚀"
description: Deep Active Directory coverage, AI data security checks with Microsoft Purview, SharePoint and GitHub security tests, Global Secure Access, contributor credits, and a sharper report experience.
slug: maester-2-2
authors: [maesterteam]
tags: [maester, release, security, entra, m365, activedirectory, purview, github]
hide_table_of_contents: false
date: 2026-07-26
---

Maester 2.2 is here, and it's our biggest expansion of security coverage yet.

Since 2.1.0 shipped in May, the community has kept up an incredible pace: 261 commits and 311 new tests. Maester now stretches all the way from your on-premises Active Directory to AI data security with Microsoft Purview, SharePoint Online, GitHub, Global Secure Access, and Intune.

<!-- truncate -->

## Highlights

- **269 Active Directory checks** across identity, policy, infrastructure, DNS, trusts, replication, and access control
- **5 Microsoft Purview checks** to get your data security foundations ready for Copilot and AI
- **12 new SharePoint Online checks** across the CIS and CISA baselines, now cross-platform with PnP.PowerShell
- **5 CIS GitHub organization controls** and first-class GitHub connectivity
- **9 Global Secure Access checks** for Private Access, forwarding profiles, Compliant Network, and Internet Access
- **4 Intune endpoint security checks** for LAPS, attack surface reduction, App Control for Business, and Managed Installer
- **New Entra ID checks** covering agent risk, directory sync safeguards, Conditional Access gaps, legacy MSOnline, and privileged first-party apps
- **A sharper report** with markdown summaries, per-test durations, and critical findings sorted first
- **Contributor credits across maester.dev**, so the people writing these tests get the recognition they deserve

## Deep Active Directory coverage

This is the big one. Maester can now test your on-premises Active Directory alongside Microsoft 365 and Microsoft Entra.

The release adds 269 opt-in AD checks across 19 areas, including:

- Users, groups, computers, and service principal names
- Password policy and fine-grained password policy
- Domain, forest, domain controller, site, subnet, and replication health
- DNS, trusts, schema, and directory configuration
- Group Policy inventory and state
- DACL and privileged access analysis

AD testing is opt-in by design. `Connect-Maester -Service All` will not touch your domain controllers. When you're ready, connect explicitly:

```powershell
Connect-Maester -Service ActiveDirectory
Invoke-Maester -Path "./ad" -SkipGraphConnect -NonInteractive
```

This first release is a preview, and we'd love your feedback: how the results look in your environment, how the checks perform in larger domains, and where the thresholds or remediation guidance could be better. [Open an issue](https://github.com/maester365/maester/issues/new/choose) or come chat in the [Maester Discord](https://discord.maester.dev/).

Special thanks to [Mike Soule](/contributors/soulemike) for building and validating this massive new area of Maester.

## Microsoft Purview and AI data security

Everyone is rolling out Copilot right now. Far fewer teams have checked whether their data security foundations are ready for it.

The new `MT.1172` to `MT.1176` checks confirm the basics are in place before AI starts touching your data:

- Unified audit log ingestion is enabled
- Sensitivity labels for files are published
- An Insider Risk Management policy covers risky AI usage
- A DLP policy covers the Microsoft 365 Copilot location
- A retention policy covers Microsoft Copilot interactions

Special thanks to [Ofir Gavish](/contributors/ofirgavish) for adding the Microsoft Purview coverage.

## SharePoint Online: CIS, CISA, and PnP.PowerShell

Maester now talks to SharePoint Online through PnP.PowerShell, and it works cross-platform.

This release adds six CIS Microsoft 365 Foundations Benchmark checks for SharePoint sharing and download controls, plus six new CISA SCuBA checks. The two existing CISA SharePoint checks moved over to the same connection, completing all eight CISA SharePoint baseline controls.

The new checks cover:

- Default sharing scope and permission
- Anyone-link expiration and permissions
- OneDrive external sharing
- Verification-code reauthentication
- Guest sharing and B2B integration
- Protection against downloading malicious files

Special thanks to [Morten Mynster](/contributors/mynster9361), [Henrik Piecha](/contributors/henrikpiecha), [Simon Albers](https://github.com/DataAndGoliath), and [PulpyJuice](https://github.com/PulpyJuice) for the SharePoint implementations and follow-up work.

## GitHub security and easier GitHub Actions setup

Your identity perimeter doesn't stop at Microsoft 365, and now Maester doesn't either. 2.2 adds first-class GitHub connectivity and five CIS GitHub organization controls:

- Strict base repository permissions
- Restricted repository creation
- Restricted repository deletion
- Restricted team creation
- Restricted issue deletion

Connect to your GitHub organization and run them alongside the rest of your security tests:

```powershell
Connect-Maester -Service GitHub
Invoke-Maester -Tag "CIS GH"
```

Setting up Maester in GitHub Actions also got a whole lot easier. From a `maester-tests` repository, Maester can now detect your Git remote, create the federated credential, and set the Actions secrets for you:

```powershell
Connect-Maester -Service Azure
New-MtMaesterApp -GitHubActions -SetGitHubSecrets
```

Special thanks to [Travis McDade](/contributors/thetechgy) for the GitHub connection and CIS controls, and [Loïc Michel](https://github.com/kayasax) for the zero-configuration GitHub Actions setup.

## Global Secure Access

If you're rolling out Microsoft Entra Global Secure Access, nine new preview checks look for the configuration mistakes that are easy to make and hard to spot:

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

These checks add one new read-only Graph permission, `NetworkAccess.Read.All`, to the default scopes.

Special thanks to [Christopher Brumm](/contributors/crmhh) for developing the checks, validating them against a live tenant, and lining them up with the Microsoft Zero Trust Assessment so the two don't overlap.

## More Intune and Entra ID checks

Four new Intune checks cover endpoint controls at the heart of a modern Windows security baseline:

- `MT.1177`: Windows LAPS configuration
- `MT.1178`: Attack Surface Reduction rules
- `MT.1179`: App Control for Business
- `MT.1180`: Managed Installer

On the Entra ID side, new checks catch high agent-risk sign-ins, Conditional Access policies with no target resources, legacy MSOnline PowerShell authentication, high-privilege first-party apps without explicit assignment, DMARC on verified domains, BitLocker recovery-key restrictions, and the protected `onPremisesObjectIdentifier` update path.

Special thanks to [Ofir Gavish](/contributors/ofirgavish), [ExeqZ](https://github.com/ExeqZ), [Jan Bakker](/contributors/bakkerjan), and [Matthias](/contributors/blindzero) for this new coverage.

## Reports, automation, and contributor credits

The report keeps getting sharper:

- Markdown summaries you can drop into pipelines and pull requests
- Per-test durations in the HTML report
- Critical findings sorted to the top
- Filtered `NotRun` results hidden by default, with a status filter if you want them back
- Less warning noise for tests you've intentionally filtered out
- Smarter skipping for tests your licenses don't cover

Behind the scenes, releases now go through automated smoke tests against a demo tenant before they ship, along with better version tracking across the module and tests.

And our favorite change in this release: maester.dev now credits the people behind every test. Authorship is derived from Git history and shown right on each test's documentation page, along with the new [contributors page](/contributors). New contributions are picked up automatically, so the credits grow with the project.

## Thank you to every contributor

Maester 2.2 includes contributions from 26 people:

- [Artem Borodai](https://github.com/artemop) for making role lookups more resilient.
- [Brian Reid](/contributors/brianreidc7) for improving the managed-domain and MFA policy checks.
- [Christopher Brumm](/contributors/crmhh) for the nine Global Secure Access checks.
- [Christopher Edwards](/contributors/korthal-maiyn) for license-aware skips in the Intune and Defender for Office 365 tests.
- [ExeqZ](https://github.com/ExeqZ) for the high agent-risk Conditional Access check.
- [Henrik Piecha](/contributors/henrikpiecha) for originating and co-authoring the SharePoint Online CIS coverage.
- [Jan Bakker](/contributors/bakkerjan) for five new Entra and CIS checks and stronger Conditional Access error handling.
- [Jean-Philippe George](/contributors/jeanphilippegeorge) for improving license-aware results, parameter handling, and documentation.
- [Jon Gross](https://github.com/jongross4) for fixing error handling in a tricky tenant edge case.
- [Jon Hope](/contributors/jhope188) for fixing ORCA and Conditional Access role-lookup edge cases.
- [Loïc Michel](https://github.com/kayasax) for the zero-configuration GitHub Actions and OIDC setup.
- [Massimo Mazzariol](/contributors/massimomazzariol) for documenting Microsoft Graph scopes in connection results.
- [Matthias](/contributors/blindzero) for the DMARC coverage and verified-domain fixes.
- [Merill Fernando](/contributors/merill) for release, report, website, and automation improvements.
- [Mike Soule](/contributors/soulemike) for building and validating the 269 Active Directory checks.
- [Morten Mynster](/contributors/mynster9361) for SharePoint Online CIS and CISA coverage, PnP.PowerShell support, and report and build fixes.
- [Ofir Gavish](/contributors/ofirgavish) for the Microsoft Purview and Intune endpoint security checks.
- [PulpyJuice](https://github.com/PulpyJuice) for co-authoring the CISA SharePoint Online follow-up.
- [Sam Erde](/contributors/samerde) for release automation, code scanning, generated documentation, version tracking, and report quality.
- [seick](/contributors/seick) for fixing workload identity policy handling and completing permission documentation.
- [Simon Albers](https://github.com/DataAndGoliath) for the SharePoint Online implementation adopted in this release.
- [Stephan van Rooij](/contributors/svrooij) for the markdown summary report.
- [Thomas Naunheim](/contributors/cloud-architekt) for improved delegated-permission support and error handling.
- [Thomas S. Schmidt](/contributors/thomas-s-schmidt) for fixing Defender for Identity health-response handling.
- [Travis McDade](/contributors/thetechgy) for GitHub connectivity and the CIS GitHub organization controls.
- [Truls Thorstad Dahlsveen](/contributors/lnfernux) for expanding the permissions documentation.

Thank you as well to everyone who reviewed a pull request, reported an issue, tested a preview build, improved the docs, or shared a "this failed in my tenant" edge case. That feedback is what turns a big pile of checks into a security testing framework you can rely on.

## Thank you to Maester's Founding Supporters

This release also marks a new chapter for me personally. I (Merill) am now working on Maester full time: maintaining the open core, keeping the checks current as Microsoft 365 changes, and giving this community the focus it deserves.

The people and organizations below were the first to back that decision through Maester Cloud. Their support creates the space for me to do this work every day, while keeping Maester's core framework and tests open and available to everyone. Every person who runs Maester benefits from their early belief in what this project can become.

My heartfelt thanks to:

- [CyberDrain / CIPP](https://cipp.app/)
- [Derek Morgan](https://www.linkedin.com/in/derek-morgan-14370775)
- [Daniel Bradley](https://www.linkedin.com/in/danielbradley2/)
- [Stefan Wey / Alweys](https://alweys.ch/maester)
- [Integrency](https://integrency.com/)
- [Conflux Cloud](https://confluxcloud.tech/)
- [Greenwire Solutions](https://greenwiresolutions.com/)
- [Martin Heusser](https://heusser.pro/)
- Erica Zelickowski
- [Ben Seaba](https://www.linkedin.com/in/benjamin-seaba-83a29957/)
- [St Vincent's Institute](https://www.svi.edu.au/)
- [Devote](https://devote.com/)
- [Crimson Owl Technologies](https://www.crimsonowl.eu/)
- [Zitac](https://www.zitac.se/en/)
- [Stevez Gomes](https://linkedin.com/in/stevezgomes)
- [TDC Erhverv](https://tdc.dk/)
- [Paul Schnackenburg](https://www.expertitsolutions.com.au/)
- [Fired Synapse Technologies, Joe Bales](https://firedsynapse.com/)
- [UpTime IT Management](https://www.uptime.net.nz/)
- [Jan Bakker](https://janbakker.tech/)
- [Declarative Ltd](https://declarative.nz/)
- [Blue Hybrid](https://bluehybrid.io/)
- [Steel Shed](https://steelshed.com/)
- [GRC Softwaremanagement AG](https://www.grcag.eu/)
- [Bastien Perez](https://perezbastien.com/)
- [Horizons Consulting, Inc.](https://www.hrizns.com/)
- [365Vantage](https://365vantage.com.au/)
- [conode Systemhaus GmbH](https://conode.de/)
- [SECOTRON (Thomas Geens)](https://www.secotron.eu/)
- David Wanderer
- [Jeff Weitz](https://www.linkedin.com/in/cjweitz/)
- [Kim Gramenske](https://www.linkedin.com/in/kim-gramenske-5a0b261a2/)
- [Thomas & Hutton](https://www.thomasandhutton.com/)
- [De Technische Jongens](https://www.detechnischejongens.nl/)
- [Langtech Inc.](https://www.langtech.com/)
- [MSX Security - Marcus Burnap](https://uk.linkedin.com/company/msx-security)

Their names now have a permanent place on the [Maester Cloud Founding Supporters wall](https://maester.cloud/founders). The [Maester Manifesto](https://maester.cloud/manifesto) explains the open-source future they are helping make possible.

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

# Microsoft Purview and AI data security
Invoke-Maester -Tag "MT.1172", "MT.1173", "MT.1174", "MT.1175", "MT.1176"

# CIS GitHub controls
Connect-Maester -Service GitHub
Invoke-Maester -Tag "CIS GH"

# Global Secure Access preview checks
Invoke-Maester -Tag "MT.1187", "MT.1188", "MT.1189", "MT.1190", "MT.1191", "MT.1192", "MT.1193", "MT.1194", "MT.1195"

# Intune endpoint security
Invoke-Maester -Tag "MT.1177", "MT.1178", "MT.1179", "MT.1180"
```

Maester 2.2 stretches from your domain controllers to your AI rollout, your SharePoint sharing settings, and your GitHub organization. And for the first time, the people building that coverage get their names on it.

Happy testing! 🎉
