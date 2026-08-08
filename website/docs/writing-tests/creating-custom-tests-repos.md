---
title: Sharing custom tests via GitHub
sidebar_position: 4
---

## Overview

The [Getting started](./index.mdx) and [Advanced guide](./advanced-concepts.md) pages show you how to add custom tests to your own **Custom** folder. Sometimes you want to go further and **share** a set of custom tests - across your own tenants, with your team, or with the wider community - as a standalone GitHub repository.

Maester supports this with `Install-MtCustomTests`, which downloads a GitHub repository, finds a `.maester` folder in it, and installs its contents into a dedicated subfolder of `Custom` named after the repository.

```powershell
Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph'
```

This installs the tests to `.\Custom\Least_Privileged_MSGraph`, ready to run alongside your other Maester tests.

:::danger Security
Custom tests are arbitrary PowerShell/Pester code pulled from a third-party repository. Maester cannot guarantee their security. `Install-MtCustomTests` always shows a confirmation prompt before installing anything - **review the source repository yourself** before accepting it, the same way you would before running any script from the internet. This prompt cannot be skipped, even with `-Force`.
:::

## Installing custom tests from a repository

`-Repository` accepts either the `owner/repo` shorthand or a full GitHub URL:

```powershell
Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph'
Install-MtCustomTests -Repository 'https://github.com/Mynster9361/Least_Privileged_MSGraph'
```

By default the tests are installed into `.\Custom\<repo name>` (relative to the folder containing your `CISA`, `EIDSCA`, `Maester` and `Custom` subfolders). Use `-Path` if your Maester tests live somewhere else:

```powershell
Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph' -Path .\maester-tests
```

Pin to a specific branch or tag with `-Branch` (defaults to the repository's default branch):

```powershell
Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph' -Branch 'v1.2.0'
```

### Updating an already-installed repository

Running `Install-MtCustomTests` again for a repository that's already installed prompts you to confirm before replacing the existing folder with the latest content. Use `-Force` to skip that specific prompt (for example, in an automated pipeline) - the security due-diligence prompt above is still always shown.

```powershell
Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph' -Force
```

### Private repositories and rate limits

`Install-MtCustomTests` works unauthenticated against public repositories. To install from a private repository, or to avoid GitHub's unauthenticated API rate limit, set an environmental variable with the name `MAESTER_GITHUB_TOKEN` or `GH_TOKEN` to a token with access to the repository before running the command.

## Publishing your own custom tests repository

Any public or private GitHub repository can be a source for `Install-MtCustomTests` - there's nothing to register or publish anywhere. All that's required is a **`.maester` folder at the root of the repository**.

```txt
your-repo/
├── .maester/
│   ├── ContosoUsers.Tests.ps1
│   ├── Test-ContosoUsersMissingManagers.ps1
│   ├── Test-ContosoUsersMissingManagers.md
│   └── maester-metadata.json   (optional, see below)
├── README.md
└── ...
```

Everything inside `.maester` is copied as-is into `Custom/<repo name>` - files, subfolders, whatever structure you prefer. Only the `.maester` folder's contents are copied; the rest of your repository (README, source for a companion PowerShell module, CI workflows, etc.) is not.

Follow the same conventions as any other custom test - see the [Getting started](./index.mdx) and [Advanced guide](./advanced-concepts.md) pages for writing `.Tests.ps1` files, splitting out markdown remediation content, and tagging. Prefix your `Describe` tags and test IDs with something specific to your repository (for example `LPMS.001`) so they're easy to distinguish from other custom tests a user may have installed.

### Giving install-time information: maester-metadata.json

If your tests have prerequisites - required PowerShell modules, external resources to configure, permissions beyond a standard Maester connection - put a `maester-metadata.json` file at the root of your `.maester` folder. `Install-MtCustomTests` reads it after installing and surfaces it to the user automatically.

```json
{
  "Message": "Free-form text shown after install - setup steps, links, configuration notes.",
  "RequiredModules": [
    "Az.Accounts",
    { "Name": "Pester", "MinimumVersion": "5.5.0" }
  ]
}
```

Both fields are optional. A missing `maester-metadata.json` is ignored. A malformed file does not block the install and produces a warning.

- **`Message`** - free-form text displayed after a successful install. Use it for setup steps, links to your documentation, or configuration reminders.
- **`RequiredModules`** - an array of PowerShell modules your tests depend on. Each entry is either a module name string, or an object with `Name` and an optional `MinimumVersion`. After install, `Install-MtCustomTests` checks `Get-Module -ListAvailable` for each entry and warns about anything missing or below the required version - it does not install them for you.

For example, a repository that queries Azure Monitor Log Analytics and needs a helper module might ship:

```json
{
    "Message": "Setup required before running these tests:\n1. Enable the 'MicrosoftGraphActivityLogs' diagnostic setting in Entra ID -> Log Analytics.\n2. Add your workspace ID to Custom/maester-config.json under GlobalSettings.LPMSLogAnalyticsWorkspaceId.\n3. Run 'Connect-AzAccount -AuthScope https://api.loganalytics.io' before Invoke-Maester.\n\nSee https://mynster-it.dk/2026/02/26/LeastPrivilegedMSGraphSetup for step by step guide.\nSee https://mynster-it.dk/docs/modules/leastprivilegedmsgraph for docs.",
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

Which produces this output after install:

```txt
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
2. Add your workspace ID to Custom/maester-config.json under GlobalSettings.LPMSLogAnalyticsWorkspaceId.
3. Run 'Connect-AzAccount -AuthScope https://api.loganalytics.io' before Invoke-Maester.

See https://mynster-it.dk/2026/02/26/LeastPrivilegedMSGraphSetup for step by step guide.
See https://mynster-it.dk/docs/modules/leastprivilegedmsgraph for docs.
```

### Configuration for your tests

If your tests need tenant-specific configuration (a workspace ID, a threshold, a feature flag), don't hardcode it - read it the same way the built-in Maester tests do, via `maester-config.json`. Document the expected settings in your README and/or your `maester-metadata.json` message, and consider shipping a `maester-config.json.example` file in `.maester` as a template users can copy from.

:::note
Never have your tests write to `tests/maester-config.json` directly - that file is overwritten whenever the user runs `Update-MaesterTests`. Tenant-specific settings belong in `Custom/maester-config.json`, which Maester preserves across updates.
:::

## Example repository

[Mynster9361/Least_Privileged_MSGraph](https://github.com/Mynster9361/Least_Privileged_MSGraph) is a full worked example: a `.maester` folder with multiple test files, a companion PowerShell module dependency, and documented Log Analytics prerequisites.

```powershell
Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph'
```

## Learn more

- [Install-MtCustomTests command reference](/docs/next/commands/Install-MtCustomTests)
- [Getting started with custom tests](./index.mdx)
- [Advanced guide](./advanced-concepts.md)
