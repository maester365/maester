# 🔥 Maester

**Monitor your Microsoft 365 tenant's security configuration using Maester!**

Maester is an open source **PowerShell-based test automation framework** designed to help you monitor and maintain the security configuration of your Microsoft 365 environment. To learn more about Maester and to get started, visit [Maester.dev](https://maester.dev).

[![PSGallery Preview Version](https://img.shields.io/powershellgallery/v/maester.svg?style=flat&logo=powershell&label=Preview%20Version&include_prereleases)](https://www.powershellgallery.com/packages/maester)
[![PSGallery Release Version](https://img.shields.io/powershellgallery/v/maester.svg?style=flat&logo=powershell&label=Release%20Version)](https://www.powershellgallery.com/packages/maester) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/maester.svg?style=flat&logo=powershell&label=PSGallery%20Downloads)](https://www.powershellgallery.com/packages/maester)

[![build-validation](https://github.com/maester365/maester/actions/workflows/build-validation.yaml/badge.svg)](https://github.com/maester365/maester/actions/workflows/build-validation.yaml)
[![publish-module-preview](https://github.com/maester365/maester/actions/workflows/publish-module-preview.yaml/badge.svg)](https://github.com/maester365/maester/actions/workflows/publish-module-preview.yaml)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/1dda297d1bb442ddb4d7411d6d2d1e82)](https://app.codacy.com/gh/maester365/maester/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

---

> [!WARNING]
>
> Known Issue: We recommend *not* using v3.9.2 of the **ExchangeOnlineManagement** module at this time. Many users experience errors while connecting with v3.9.2 but previous versions are generally reliable. This is an issue with the ExchangeOnlineManagement module and not Maester itself.

## Key Features

- **Automated Testing**: Maester provides a comprehensive set of automated tests to ensure the security of your Microsoft 365 setup.
- **Customizable**: Tailor Maester to your specific needs by adding custom Pester tests.
- **Formatted Results**: Export results in CSV, Excel, HTML, JSON, or Markdown format.
- **Notifications**: Send notification of results to email, Teams, or Slack.
- **CI/CD Workflows**: Run Maester in a GitHub, Azure DevOps, or GitLab pipeline.
- **And much more...**

---

## Getting Started

### Installation

```powershell
Install-Module -Name Maester -Scope CurrentUser
```

### Installing Maester Tests

Run the following commands to install the Maester tests under your home directory. Pester will be installed if needed.

```powershell
md ~/maester-tests
cd ~/maester-tests
Install-MaesterTests
```

## Running Maester

To run the tests in this folder run the following PowerShell commands. To learn more see [maester.dev](https://maester.dev).

```powershell
cd ~/maester-tests
Connect-Maester
Invoke-Maester
```

### Running Maester in a National Cloud Environment

An optional parameter, `-Environment`, can be utilized on `Connect-Maester` to specify the name of the national cloud environment to connect to. By default global cloud is used.

Allowed values include:

- Global (default, if parameter is not specified)
- China
- USGov
- USGovDOD

```powershell
Connect-Maester -Environment USGov
```

## Keeping your Maester tests up to date

The Maester team will add new tests over time. To get the latest updates, use the commands below to update this folder with the latest tests.

- Update the `Maester` PowerShell module to the latest version and load it.
- Use `Update-MaesterTests` to update the test files in the folder where you have installed them.

```powershell
Update-Module Maester -Force
Import-Module Maester
Update-MaesterTests -Path ~/maester-tests
```

## Use as GitHub action

Maester is also published to the [GitHub marketplace](https://github.com/marketplace/actions/run-maester) and can be used directly in any GitHub workflow. Because it is built for GitHub, it integrates with the features of GitHub Actions, like uploading artifacts and writing a summary to the workflow run.

For more details, please refer to the [docs](https://maester.dev/docs/monitoring/github/) or the [action repository](https://github.com/maester365/maester-action).

### Migrate from old action

The GitHub Action is moved to a new [repository](https://github.com/maester365/maester-action).

> [!NOTE]
> If you are using the old action `maester365/maester` you should migrate to the new action `maester365/maester-action`. Check out the [deprecation notice](https://github.com/maester365/maester/blob/main/action/deprecation.md) for more details.

## Contributing

Contributions are welcome! If you want to contribute new tests or improve existing ones, please refer to the [contribution guide](https://preview.maester.dev/docs/contributing).
