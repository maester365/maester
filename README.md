# 🔥 Maester

**Monitor your Microsoft 365 tenant's security configuration using Maester!**

> [!WARNING]
> **Maester 3.0 is now the preview build**
>
> The **preview** build on the PowerShell Gallery is now Maester 3.0. It has breaking changes: most notably, **PowerShell 7.4 or later is required** (Windows PowerShell 5.1 is no longer supported). Custom tests, including Pester tests, keep working; `Convert-MtTest` converts them to the new native format.
>
> **If your automation installs the preview build** (`-AllowPrerelease`, or `maester_version: preview` in the GitHub Action) and isn't ready for 3.0, **switch to the release build**: drop `-AllowPrerelease` or pin `-RequiredVersion 2.3.0`, and use `maester_version: latest` in the action.
>
> Read the [Maester 3.0 announcement](https://maester.dev/blog/maester-3-0) and [Upgrading from 2.x](https://maester.dev/docs/next/upgrading-from-2x).

> [!NOTE]
> **Contributions are open again**
>
> The Maester 3.0 rewrite is in `main`. Checks are now native tests (`Test.<ID>.ps1` and `Test.<ID>.md`), and the repository has a new folder layout. Before you open a pull request, read [Writing tests](https://maester.dev/docs/next/writing-tests) and the [contributing guide](https://maester.dev/docs/next/contributing#repository-layout). If your pull request was opened before 3.0, rebase it on `main`; `Convert-MtTest` converts Pester-format checks to native tests.

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
- **Customizable**: Tailor Maester to your specific needs with your own tests, per-tenant configuration and test parameters.
- **Formatted Results**: Export results in CSV, Excel, HTML, JSON, or Markdown format.
- **Notifications**: Send notification of results to email, Teams, or Slack.
- **CI/CD Workflows**: Run Maester in a GitHub, Azure DevOps, or GitLab pipeline.
- **And much more...**

---

## Getting Started

### Installation

Maester needs PowerShell 7.4 or later on Windows, Linux or macOS.

```powershell
Install-Module -Name Maester -Scope CurrentUser
```

The tests ship inside the module, so there is nothing else to install or download.

## Running Maester

```powershell
Connect-Maester
Invoke-Maester
```

To also run your own tests, or to change settings with a `maester-config.json`, keep them in a folder and pass it with `-Path` (or run from that folder):

```powershell
Invoke-Maester -Path ~/maester
```

To learn more see [maester.dev](https://maester.dev).

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

The Maester team will add new tests over time. The tests ship inside the module, so updating the module updates the tests:

```powershell
Update-Module Maester -Force
```

Upgrading from Maester 2.x? Copies of the tests that `Install-MaesterTests` wrote in 2.x are no longer used. Remove them with `Update-MaesterTests -Path ./maester-tests` (use the path of your 2.x tests folder). If the folder holds no custom tests and no `maester-config.json` changes you want to keep, you can delete it instead. See [Upgrading from 2.x](https://maester.dev/docs/upgrading-from-2x) for everything else that changed.

## Writing your own tests

A Maester test is two files: `Test.<ID>.ps1`, a PowerShell function with a `[MaesterTest(...)]` attribute, and `Test.<ID>.md` with its description and remediation steps.

```powershell
New-MtTest -Id CONTOSO.1001 -Title 'Guest invitations are restricted' -Service Graph   # scaffold custom/Test.CONTOSO.1001.*
Get-MtTest -Path ./custom                                                            # validate, no tenant needed
Invoke-MtTest -Path ./custom/Test.CONTOSO.1001.ps1                                   # run one test
```

Custom tests written for 2.x with Pester still run when Pester 5.7.1 or later is installed, and `Convert-MtTest` converts them. See [Writing native tests](https://maester.dev/docs/writing-tests).

## Use as GitHub action

Maester is also published to the [GitHub marketplace](https://github.com/marketplace/actions/run-maester) and can be used directly in any GitHub workflow. Because it is built for GitHub, it integrates with the features of GitHub Actions, like uploading artifacts and writing a summary to the workflow run.

For more details, please refer to the [docs](https://maester.dev/docs/monitoring/github/) or the [action repository](https://github.com/maester365/maester-action).

### Migrate from old action

The GitHub Action is moved to a new [repository](https://github.com/maester365/maester-action).

> [!NOTE]
> If you are using the old action `maester365/maester` you should migrate to the new action `maester365/maester-action`. Check out the [deprecation notice](https://github.com/maester365/maester/blob/main/action/deprecation.md) for more details.

## Building from source

Maester's source code lives in the `powershell/` and `tests/` folders. To produce the publishable module locally, run the build script from the repository root:

```powershell
./build/Build-LocalMaester.ps1
```

This builds and validates the module, unloads any other Maester module, and
imports the local build into the current PowerShell session. Run `Invoke-Maester`
to run the built-in tests from the local build.

From a source checkout you can also import `./powershell/Maester.psd1` directly: it loads the native tests from
`./tests` and the committed engine DLL, so no build and no .NET SDK are needed unless you change the engine in
`src/Maester.Engine`.

After changing the report, use `./build/Build-LocalMaester.ps1 -BuildReport` to
build and embed the report template before building and importing the module.

The `module/` folder is a build artifact — it is ignored by git and never committed to source control. Built modules are attached to each [GitHub Release](https://github.com/maester365/maester/releases) and published to the PowerShell Gallery from CI. See the [contributing guide](https://maester.dev/docs/contributing) for full details.

## Contributing

Contributions are welcome! If you want to contribute new tests or improve existing ones, please refer to the [contribution guide](https://maester.dev/docs/contributing).

<!-- sponsors:start -->
<!-- Written by website/scripts/sponsors.mjs. To change the featured sponsors, edit website/sponsors/featured.yml. -->

## Sponsors

Thank you to the organisations and people who sponsor Maester and its maintainers. You make Maester possible.

<p>
  <a href="https://cyberdrain.com"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/maester365/maester/main/website/static/img/sponsors/cyberdrain-dark.png"><img src="https://raw.githubusercontent.com/maester365/maester/main/website/static/img/sponsors/cyberdrain.png" alt="CyberDrain" height="52"></picture></a>&nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://www.increment.inc"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/maester365/maester/main/website/static/img/sponsors/increment-dark.png"><img src="https://raw.githubusercontent.com/maester365/maester/main/website/static/img/sponsors/increment.png" alt="Increment" height="52"></picture></a>
</p>

<table>
  <tr>
    <td align="center" width="110"><a href="https://github.com/merill"><img src="https://avatars.githubusercontent.com/u/1288081?s=120&amp;u=57eb374fa2f7b642ddc37f6ebf4c926b3cc13b76&amp;v=4" width="64" height="64" alt=""><br><sub><b>Merill Fernando</b></sub></a></td>
    <td align="center" width="110"><a href="https://github.com/RobinpZA"><img src="https://avatars.githubusercontent.com/u/165141638?s=120&amp;u=44e0f1186bb519fbcef14e33fd2b5838e2f3a830&amp;v=4" width="64" height="64" alt=""><br><sub><b>Robin Pieterse</b></sub></a></td>
  </tr>
</table>

Using Maester at work? Ask your company to sponsor one of the [people who build it](https://maester.dev/sponsor).
<!-- sponsors:end -->
