# 🔥 Maester

**Monitor your Microsoft 365 tenant's security configuration using Maester!**

Maester is an open source **PowerShell-based test automation framework** designed to help you monitor and maintain the security configuration of your Microsoft 365 environment.

To learn more about Maester and to get started, visit [Maester.dev](https://maester.dev).

[![PSGallery Preview Version](https://img.shields.io/powershellgallery/v/maester.svg?style=flat&logo=powershell&label=Preview%20Version&include_prereleases)](https://www.powershellgallery.com/packages/maester) [![PSGallery Release Version](https://img.shields.io/powershellgallery/v/maester.svg?style=flat&logo=powershell&label=Release%20Version)](https://www.powershellgallery.com/packages/maester) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/maester.svg?style=flat&logo=powershell&label=PSGallery%20Downloads)](https://www.powershellgallery.com/packages/maester)

[![build-validation](https://github.com/maester365/maester/actions/workflows/build-validation.yaml/badge.svg)](https://github.com/maester365/maester/actions/workflows/build-validation.yaml)
[![publish-module-preview](https://github.com/maester365/maester/actions/workflows/publish-module-preview.yaml/badge.svg)](https://github.com/maester365/maester/actions/workflows/publish-module-preview.yaml)
---

## Key Features

- **Automated Testing**: Maester provides a comprehensive set of automated tests to ensure the security of your Microsoft 365 setup.
- **Customizable**: Tailor Maester to your specific needs by adding custom Pester tests.
- **More to come...**

---

## Getting Started

### Installation

```powershell
Install-Module -Name Maester -Scope CurrentUser
```

### Installing Maester Tests

To install the Maester tests run the following PowerShell commands. Pester will be installed if needed.

```powershell
md maester-tests
cd maester-tests
Install-MaesterTests
```

## Running Maester

To run the tests in this folder run the following PowerShell commands. To learn more see [maester.dev](https://maester.dev).

```powershell
Connect-Maester
Invoke-Maester
```

### Running Maester in a National Cloud Environment

An optional parameter, `-Environment`, can be utilized on `Connect-Maester` to specify the name of the national cloud environment to connect to. By default global cloud is used.

Allowed values include:

- Global (default, if parameter is not specified)
- China
- Germany
- USGov
- USGovDOD

```powershell
Connect-Maester -Environment USGov
```

## Keeping your Maester tests up to date

The Maester team will add new tests over time. To get the latest updates, use the commands below to update this folder with the latest tests.

- Update the `Maester` PowerShell module to the latest version and load it.
- Navigate to the folder where you have your Maester tests.
- Run `Update-MaesterTests`.

```powershell
Update-Module Maester -Force
Import-Module Maester
Update-MaesterTests
```

## Use as GitHub action

Maester is also published to the [GitHub marketplace](https://github.com/marketplace/actions/run-maester) and can be used directly in any GitHub workflow. Because it is built for GitHub, it integrates with the features of GitHub Actions, like uploading artifacts and writing a summary to the workflow run.

For more details, please refer to the [docs](https://maester.dev/docs/monitoring/github/) or the [action repository](https://github.com/maester365/maester-action).

```yaml
name: Daily tests

on:
  push:
    branches: ["main"]
  # Run once a day at midnight
  schedule:
    - cron: "0 6 * * *"
  # Allows to run this workflow manually from the Actions tab
  workflow_dispatch:

permissions:
      id-token: write # important because the actions needs it to authenticate to Entra using workload identity
      contents: read
      checks: write

jobs:
  daily-tests:
    name: Daily security scan
    runs-on: ubuntu-latest
    steps:
    - name: Maester 🔥
      id: maester # this is important, by setting the id you can use the output of the action in the next steps
      uses: maester365/maester-action@v1.0.1 # this is the new action
      with:
        client_id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant_id: ${{ secrets.AZURE_TENANT_ID }}
        include_public_tests: true # Optional
        include_private_tests: true # Optional
        include_exchange: false # Optional
        include_teams: false # Optional
        pester_verbosity: None # Optional - 'None', 'Normal', 'Detailed', 'Diagnostic'
        step_summary: true         # Optional: Set to false if you don't want a summary added to your GitHub Action run
        artifact_upload: true      # Optional: Set to false if you don't want summaries uploaded to GitHub Artifacts
        maester_version: latest  # Optional: Set to 'latest' or 'preview' to use the latest version of the Maester module or a specific version like '1.0.83-preview'
        disable_telemetry: false   # Optional: Set to true If you want telemetry information not to be logged.
```

### Migrate from old action

The Github Action is moved to a new [repository](https://github.com/maester365/maester-action).

> [!NOTE]
> If you are using the old action `maester365/maester` you should migrate to the new action `maester365/maester-action`. Check out the [deprecation notice](https://github.com/maester365/maester/blob/main/action/deprecation.md) for more details.
