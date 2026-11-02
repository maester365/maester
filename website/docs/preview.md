---
title: Get the preview
description: How to install the Maester preview to use checks and commands that aren't in the stable release yet, how to use it in your pipelines, and how to go back to the stable release.
sidebar:
  label: Get the preview
  order: 3
---

Maester ships on two channels:

- **Stable** releases come out every few weeks. Most people, and most pipelines, should run stable.
- A **preview** is published to the PowerShell Gallery every time a change is merged. It has every new check, command and option as soon as it is merged, before the next stable release.

These docs describe the preview. A check, command or parameter that the stable release doesn't have yet is marked **Preview** on its page and in the [test catalog](/docs/tests). Pick the version you run from the version menu at the top of the page, and the marks say what your version doesn't have.

## Install the preview

```powershell
Install-Module Maester -AllowPrerelease -Force -Scope CurrentUser
```

Check which version PowerShell loads:

```powershell
Get-Module Maester -ListAvailable | Select-Object Name, Version, PrivateData
Import-Module Maester -Force
Get-Module Maester
```

A preview version ends in `-preview` followed by a number, for example `3.1.0-preview04`.

If you use PSResourceGet instead of PowerShellGet:

```powershell
Install-PSResource Maester -Prerelease -Reinstall
```

## Use the preview in automation

**GitHub Actions.** Set `maester_version` to `preview` in the Maester action:

```yaml
- uses: maester365/maester-action@main
  with:
    tenant_id: ${{ secrets.AZURE_TENANT_ID }}
    client_id: ${{ secrets.AZURE_CLIENT_ID }}
    maester_major_version: "3"
    maester_version: preview
```

**Azure DevOps, Azure Automation and other pipelines.** Install the module with `-AllowPrerelease`:

```powershell
Install-Module Maester -AllowPrerelease -Force -Scope CurrentUser
```

The preview changes with every merge. For a pipeline other people rely on, run the preview in a second, non-blocking job next to your stable job, or pin an exact preview version with `-RequiredVersion 3.1.0-preview04 -AllowPrerelease`.

## Go back to the stable release

```powershell
Uninstall-Module Maester -AllVersions -AllowPrerelease -Force
Install-Module Maester -Force -Scope CurrentUser
```

In GitHub Actions, set `maester_version` back to `latest`.

## Preview releases and preview checks

Two different things are called preview:

- **The preview release** is the module version described on this page. Install it with `-AllowPrerelease`.
- **A preview check** is a check that is still being tested or depends on a preview Microsoft API. It ships in any release, stable or preview, but only runs when you add `-IncludePreview` to `Invoke-Maester`. Its page says so.

## Tell us what you find

The preview is how new checks get tested on real tenants before they reach everyone. If something fails or reads wrong, open an issue on [GitHub](https://github.com/maester365/maester/issues) or ask in [Discord](https://discord.maester.dev).
