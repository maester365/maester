---
title: Running Invoke-Maester
description: How to choose which tests Invoke-Maester runs, where it writes the results, how to run it unattended, and how it adapts its console output to a terminal, a pipeline or a log file.
sidebar:
  order: 1
---

# Running Invoke-Maester

`Invoke-Maester` runs the tests and writes the report. This page covers the options you use most: which tests
run, where the results go, and how the command behaves on your own terminal compared with a pipeline. The
[command reference](../commands/Invoke-Maester.mdx) lists every parameter.

```powershell
Connect-Maester
Invoke-Maester
```

With no parameters, `Invoke-Maester`:

- runs the tests that ship with Maester and the custom tests in the `Custom` folder of the current folder,
- leaves out preview tests, long-running tests, Active Directory tests and installed packs,
- runs only the tests of the services you are connected to,
- writes the html, markdown and json reports to `./test-results` and opens the html report in your browser.

Every test Maester knows about is in the result, whether it ran or not. A test that did not run carries the
reason; see [Applicability and reason codes](./applicability.mdx).

## Choose the tests

### By ID

```powershell
# One test
Invoke-Maester -TestId MT.1005

# Several, with wildcards
Invoke-Maester -TestId 'MT.1005', 'CISA.MS.AAD.3.*'

# Everything except these
Invoke-Maester -ExcludeTestId 'MT.1024.*'
```

IDs are not case-sensitive and `*` is a wildcard. A test named by its exact ID in `-TestId` runs even if it is a
preview or long-running test. `-ExcludeTestId` wins over `-TestId`.

### By product, suite, area, feature or severity

Each built-in test declares what it is about. These parameters select on those attributes:

| Parameter | Selects | Example values |
| --- | --- | --- |
| `-Product` | The product whose settings the test reads | `entra`, `exchange`, `teams`, `sharepoint`, `defender`, `intune`, `purview`, `azure`, `github`, `ad` |
| `-ExcludeProduct` | Leaves out a product | the same values as `-Product` |
| `-Suite` | The set of tests it belongs to | `maester`, `cis`, `cisa`, `asd`, `disa`, `eidsca`, `orca`, `ad` |
| `-Area` | The security area | `authentication`, `privileged-access` |
| `-Feature` | A feature of a product | `conditional-access` |
| `-Severity` | How urgent a failure is | `Critical`, `High`, `Medium`, `Low`, `Info` |

```powershell
# The Entra tests
Invoke-Maester -Product entra

# Entra and Exchange Online, Critical and High only
Invoke-Maester -Product entra, exchange -Severity Critical, High

# Everything except Exchange Online and Teams
Invoke-Maester -ExcludeProduct exchange, teams

# The CISA tests about authentication
Invoke-Maester -Suite cisa -Area authentication

# The Conditional Access tests
Invoke-Maester -Feature conditional-access
```

The rules for combining them:

- The values of one parameter are alternatives: `-Product entra, exchange` is Entra **or** Exchange Online.
- Different parameters must all match: `-Product entra -Severity High` is Entra **and** High.
- `-Product` also matches a test's related products, and accepts aliases such as `'Entra ID'` or `exo`.
- `-Product`, `-ExcludeProduct`, `-Suite`, `-Area` and `-Feature` accept `*` wildcards.
- `-ExcludeProduct` and `-ExcludeTestId` win over every selector.
- A Pester-format custom test has no product, so `-ExcludeProduct` never leaves it out.

The [test catalog](/docs/tests) shows the product, area, feature and severity of every test.

:::note
The `-Tag` and `-ExcludeTag` values of Maester 2.x still select the same built-in tests, but tests added since
3.0 carry no such tags. Use the parameters above instead; see
[Upgrading from 2.x](../upgrading-from-2x.md#tags) for the selector that replaces each tag.
:::

### Preview and long-running tests

```powershell
Invoke-Maester -IncludePreview -IncludeLongRunning
```

Preview tests are new. They are left out of a default run so you can try them first and tell us what you find
before they become part of every run; include them to test them and
[give feedback](https://github.com/maester365/maester/issues). Long-running tests can take a long time in a
tenant with many objects. Both are left out unless you ask for them or name the test by its exact ID.

### Custom tests

```powershell
# Built-in tests plus the custom tests and maester-config.json in ./maester
Invoke-Maester ./maester

# Only your custom tests
Invoke-Maester -Path ./maester/Custom -SkipBuiltIn
```

See [Writing custom tests](../writing-tests/index.mdx).

### Maester Packs

A pack is a set of tests that someone else publishes and you add to your runs. A pack never runs just because
it is there: it runs only when you name it with `-Pack`, use `-AllPacks`, or turn it on in the configuration.

```powershell
# Built-in tests plus one pack
Invoke-Maester -Pack ZTA

# Only that pack
Invoke-Maester -Pack ZTA -SkipBuiltIn

# Built-in tests plus every installed pack
Invoke-Maester -AllPacks

# No packs at all, whatever the configuration turns on
Invoke-Maester -SkipPack
```

`-Pack` takes a pack's code or its ID, and accepts `*` wildcards. A pack you name runs with its preview and
long-running tests included. See [Maester Packs](../packs/index.md) to find and install packs.

:::tip[Zero Trust Assessment]
The `ZTA` pack ships with Maester, so there is nothing to install with `Install-MtPack`. It runs Microsoft's
[Zero Trust Assessment](https://aka.ms/zerotrust/assessment) and shows each of its results in the Maester
report, next to Maester's own checks.

```powershell
Install-Module ZeroTrustAssessment -Scope CurrentUser
Connect-Maester
Invoke-Maester -Pack ZTA
```

The assessment needs PowerShell 7.6 or later. See the
[Zero Trust Assessment pack](../packs/zero-trust-assessment.md).
:::

### Active Directory

Active Directory tests run only after you connect to it, and need no Microsoft Graph connection:

```powershell
Connect-Maester -Service ActiveDirectory
Invoke-Maester -Product ad
```

### Check before you run

`-DryRun` works out which tests would run, and why the others would not, without running any of them:

```powershell
$plan = Invoke-Maester -Product entra -DryRun -PassThru
$plan.Tests | Group-Object ReasonCode
```

A test that would have run has the reason code `DryRun`. The report files are still written, so you can open
the report and look at the plan. Pester-format custom tests still go through Pester discovery, which runs their
`BeforeDiscovery` and `Describe`-level code.

### Keep a selection in a file

Anything you select on the command line can live in `maester-config.json` instead, so a scheduled run and a run
on your own machine choose the same tests. See the
[run configuration reference](./run-configuration.md).

## Choose where the results go

| Parameter | What it does |
| --- | --- |
| `-OutputFolder` | Writes every format (html, markdown, markdown summary, json) to this folder, with a timestamp in the file names. Defaults to `./test-results` when no `-Output*` parameter is set. |
| `-OutputFolderFileName` | The file name to use in the output folder, instead of the timestamped one. |
| `-OutputHtmlFile`, `-OutputMarkdownFile`, `-OutputMarkdownSummaryFile`, `-OutputJsonFile` | Writes only the formats you name, each to the file given. Ignored when `-OutputFolder` is set. |
| `-ExportCsv`, `-ExportExcel` | Adds a CSV or Excel file to the output folder. |
| `-PassThru` | Returns the results as an object, for a script that goes on to read them. |
| `-MailRecipient`, `-TeamId` and `-TeamChannelId`, `-TeamChannelWebhookUri` | Sends the results by mail or posts a summary to a Teams channel. See [Alerts](../alerts/readme.mdx). |

See [Exporting results](../export-results.md) for the formats and the
[result schema](../result-schema.md) for the object and the json file.

## Run unattended

In a scheduled task, a pipeline or any script nobody watches, add `-NonInteractive`:

```powershell
$results = Invoke-Maester -NonInteractive -PassThru -OutputFolder ./test-results
if ($results.FailedCount -gt 0) { exit 1 }
```

`-NonInteractive` leaves out the logo, the dashboard, the connection details, the run summary and the check for
a newer version, and does not open the report in a browser. Warnings and errors are still written.

Without it, Maester opens the html report whenever PowerShell says the session is interactive. A build agent
can report that too; opening the report then fails and Maester writes a warning. `-NonInteractive` avoids that.
Starting PowerShell itself with `pwsh -NonInteractive` has the same effect on the browser.

See [Automate](../monitoring/readme.mdx) for ready-made pipelines.

## How the console output adapts

`Invoke-Maester` writes to the console in one of three modes. With `-OutputMode Auto`, the default, it looks at
where it is running and picks one.

| Mode | What you see | Picked when |
| --- | --- | --- |
| `Interactive` | A full-screen dashboard: the phases of the run, a progress bar, the tests that are running, result counts and panels about the tenant. When the run ends your screen is restored and the summary is written. | You run it yourself in a terminal. |
| `Stream` | Lines only, with a progress line every 50 tests or 10 seconds. Nothing is redrawn, so it reads well in a log. | A pipeline, redirected output, `-NonInteractive`, or a host that cannot draw the dashboard. |
| `Plain` | `Stream` without colour or Unicode symbols. | `TERM` is `dumb`. |

### What Maester checks

The mode is decided in this order. The first one that applies wins.

1. `-OutputMode Interactive`, `Stream` or `Plain`.
2. The `MAESTER_OUTPUT_MODE` environment variable, with the same values.
3. `Output.ConsoleMode` in [`maester-config.json`](./run-configuration.md).
4. Detection:

   | What Maester finds | Mode |
   | --- | --- |
   | `TERM=dumb` | `Plain` |
   | GitHub Actions (`GITHUB_ACTIONS=true`), Azure Pipelines (`TF_BUILD=True`) or another CI system (`CI` set to anything but `false`) | `Stream` |
   | Output is redirected to a file or a pipe | `Stream` |
   | `-NonInteractive` | `Stream` |
   | The PowerShell host is not the console host, or the terminal does not support virtual terminal sequences | `Stream` |
   | None of the above | `Interactive` |

Asking for `Interactive` where the dashboard cannot be drawn (redirected output, a host that is not the console
host) gives you `Stream`.

### The dashboard

- It needs a console of at least 80 columns and 16 rows. In a smaller one, Maester keeps a two-line status at
  the bottom of the console instead.
- The panels on the right appear when the console is about 140 columns or wider. `Output.DashboardPanels` in the
  [run configuration](./run-configuration.md#output) chooses the panels and their order.
- `-Verbosity Normal` writes one line for each finished test, and `Detailed` also a line when each test starts.
  The lines need the scrollback, so the two-line status is used instead of the full-screen dashboard.
- Warnings and errors written while the dashboard is on screen are held back and written once the run ends, so
  none are lost.
- In Windows Terminal and the VS Code terminal, Maester switches the console to UTF-8 for the run so the
  dashboard can be drawn, and puts the earlier encoding back afterwards.

To turn the dashboard off on your own terminal:

```powershell
Invoke-Maester -OutputMode Stream
```

or set it once for every run:

```powershell
$env:MAESTER_OUTPUT_MODE = 'Stream'
```

### Pipelines

On GitHub Actions and Azure Pipelines, `Stream` also:

- folds parts of the output into collapsible log groups,
- writes the first 20 `Failed` rows as warning annotations and `Error` rows as error annotations. Set
  `Output.CIAnnotations` to `false` in the run configuration to leave them out.

### Colour

- Setting the `NO_COLOR` environment variable turns colour off in every mode. So does `TERM=dumb` and
  `$PSStyle.OutputRendering = 'PlainText'`.
- Output redirected to a file or a pipe gets no colour codes, unless you asked for a mode or the CI system is
  known to render them.
- `-NoLogo` leaves out only the logo.

## See also

- [Invoke-Maester command reference](../commands/Invoke-Maester.mdx)
- [Configuration overview](./overview.md)
- [Run configuration reference](./run-configuration.md)
- [Applicability and reason codes](./applicability.mdx)
