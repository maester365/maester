---
title: "Bring Your Own Tests: Install Custom Maester Checks From Any GitHub Repo"
description: Share and install custom Maester tests as standalone GitHub repositories with the new Install-MtCustomTests command.
slug: create-your-own-repo-tests
authors: [mynster9361]
tags: [feature, custom-tests, github]
hide_table_of_contents: false
date: 2026-08-08
---

Writing a custom Maester test has always been easy - drop a `.Tests.ps1` file in your `Custom` folder and you're done. Sharing one with your team, across your own tenants, or with the community meant a lot of copy-pasting. Not anymore. 🎁

Maester now has `Install-MtCustomTests`, a command that installs a set of custom tests straight from a GitHub repository - no manual copying, no forking the whole Maester repo.

<!-- truncate -->

```powershell
Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph'
```

That's it. Maester downloads the repository, finds its `.maester` folder, and installs the tests into `Custom/Least_Privileged_MSGraph`, ready to run alongside everything else:

```powershell
Invoke-Maester
```

### Quick Stats

- 📦 Install custom tests from any public or private GitHub repository with one command
- 🔀 `owner/repo` shorthand or a full GitHub URL, pinned to a branch or tag if you need it
- 🔐 Private repos and higher API rate limits supported via `MAESTER_GITHUB_TOKEN` / `GH_TOKEN`
- 🛡️ A due-diligence confirmation is always shown before installing - Maester can't vet third-party code for you
- 📋 An optional `maester-metadata.json` file lets test authors show setup instructions and flag required PowerShell modules automatically after install

### Why the confirmation prompt?

Custom tests are PowerShell/Pester code that runs on your machine or in your pipeline with whatever permissions that session has. Maester has no way to guarantee the security of code published by someone else - so before anything is downloaded and installed, you'll always see a reminder to review the source repository yourself first. This prompt shows every time, even with `-Force`.

### Publishing your own repository

Any GitHub repository can be a source - there's nothing to register. Add a `.maester` folder at the repository root with your test files, and anyone can install it:

```
your-repo/
├── .maester/
│   ├── ContosoUsers.Tests.ps1
│   ├── Test-ContosoUsersMissingManagers.ps1
│   ├── Test-ContosoUsersMissingManagers.md
│   └── maester-metadata.json   (optional)
├── README.md
└── ...
```

If your tests have prerequisites, ship a `maester-metadata.json` alongside them:

```json
{
    "Message": "Setup required before running these tests:\n1. Enable the 'MicrosoftGraphActivityLogs' diagnostic setting in Entra ID -> Log Analytics.\n2. Add your workspace ID to tests/Custom/maester-config.json under GlobalSettings.LPMSLogAnalyticsWorkspaceId.\n3. Run 'Connect-AzAccount -AuthScope https://api.loganalytics.io' before Invoke-Maester.\n\nSee https://mynster-it.dk/2026/02/26/LeastPrivilegedMSGraphSetup for step by step guide.\nSee https://mynster-it.dk/docs/modules/leastprivilegedmsgraph for docs.",
    "RequiredModules": [
        {
            "Name": "LeastPrivilegedMSGraph",
            "MinimumVersion": "3.3.0"
        },
        {
            "Name": "Az.Accounts",
            "MinimumVersion": "5.5.0"
        },
        {
            "Name": "EntraAuth",
            "MinimumVersion": "1.8.55"
        },
        {
            "Name": "EntraAuth.Graph",
            "MinimumVersion": "1.0.5"
        },
        {
            "Name": "PSFramework",
            "MinimumVersion": "1.14.457"
        }
    ]
}
```

`Install-MtCustomTests` checks `RequiredModules` against what's actually installed and warns about anything missing, then shows your `Message` - so the person installing your tests knows exactly what to do next, without having to go read your README first:

```
Custom Maester tests from 'Mynster9361/Least_Privileged_MSGraph' installed successfully to .\Custom\Least_Privileged_MSGraph!
WARNING: 'Mynster9361/Least_Privileged_MSGraph' requires PowerShell modules that are not installed (or are below the required version):
  - LeastPrivilegedMSGraph (>= 3.3.0)
  - Az.Accounts (>= 5.5.0)
  - EntraAuth (>= 1.8.55)
  - EntraAuth.Graph (>= 1.0.5)
  - PSFramework (>= 1.14.457)
Install them with: Install-Module <name> -Scope CurrentUser

Notes from 'Mynster9361/Least_Privileged_MSGraph':
Setup required before running these tests:
1. Enable the 'MicrosoftGraphActivityLogs' diagnostic setting in Entra ID -> Log Analytics.
2. Add your workspace ID to tests/Custom/maester-config.json under GlobalSettings.LPMSLogAnalyticsWorkspaceId.
3. Run 'Connect-AzAccount -AuthScope https://api.loganalytics.io' before Invoke-Maester.

See https://mynster-it.dk/2026/02/26/LeastPrivilegedMSGraphSetup for step by step guide.
See https://mynster-it.dk/docs/modules/leastprivilegedmsgraph for docs.
```

### Get Started

- Documentation: [Sharing custom tests via GitHub](/docs/next/writing-tests/creating-custom-tests-repos)
- Command reference: [Install-MtCustomTests](/docs/next/commands/Install-MtCustomTests)
- Example repository: [Mynster9361/Least_Privileged_MSGraph](https://github.com/Mynster9361/Least_Privileged_MSGraph) - a full worked example with multiple tests, a companion module dependency, and a `maester-metadata.json` in the wild.

We can't wait to see what the community builds and shares. If you publish a custom tests repository, let us know on [Discord](https://discord.maester.dev/) or [GitHub Discussions](https://github.com/maester365/maester/discussions) - we'd love to link to it.

## Contributor

- [Morten Mynster](/blog/authors/mynster9361)
