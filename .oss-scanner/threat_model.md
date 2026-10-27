# Threat model

## What Maester does

Maester is a PowerShell 7.4+ module that checks the security configuration of a Microsoft 365 tenant. An administrator,
or a scheduled pipeline (GitHub Actions, Azure DevOps, Azure Automation), signs in with an account or app registration
that can read tenant configuration through Microsoft Graph, Exchange Online, Teams, Azure and related APIs, runs the
checks under `tests/`, and gets an HTML report, JSON, Markdown and optional email or Teams notifications.

The operator is trusted. The machine that runs Maester is trusted. The tokens it holds are high value: they usually
grant read access to a whole tenant's directory and policies, and sometimes `Mail.Send` or other write permissions.

## Where untrusted input enters

- **Tenant data.** Display names, app names, policy names, group names, domain names, URLs and other values returned by
  Graph and the other APIs can be set by anyone with low privilege in the tenant (a guest, a user who can register
  apps, a vendor's multi-tenant app). These values flow into test result Markdown, the HTML report, the console
  dashboard, email and Teams messages. Tenant values must be escaped with `Get-MtSafeMarkdown` before they go into
  result Markdown.
- **The HTML report.** `report/` is a React app built into a single HTML template; `Get-MtHtmlReport` embeds the result
  JSON in it. Report files are shared and opened by other people, so script execution, remote content loading or
  link spoofing from tenant data is in scope.
- **Result files read back in.** `Import-MtMaesterResult`, `Merge-MtMaesterResult` and `Compare-MtTestResult` read
  JSON written by an earlier run, which may come from another person or a pipeline artifact.
- **Internet lookups.** Domain checks read DNS records (SPF, DKIM, DMARC, MX and others) and some checks call public
  HTTP endpoints. Whoever controls a domain or endpoint controls those responses.
- **Custom tests and settings.** Users run their own tests and `maester-config.json` settings. Code in a custom test is
  trusted by design; a settings file or test metadata that leads to code execution it should not is in scope.
- **CI integration.** `action.yml` (the legacy GitHub Action) and the workflows under `.github/workflows/` run with
  repository secrets and tenant credentials. Injection from issue, pull request or input values into scripts is in scope.

## Components that matter most / least

Most important:
- `powershell/` (the module): connection and token handling (`public/connect/`, `internal/connect/`), report generation (`public/report/`, `internal/report/`), and anything that builds commands,
  file paths, URLs or Markdown from tenant data.
- `src/Maester.Engine/` (the C# engine: test discovery, scheduling, attribute parsing, console renderer).
- `report/` (the HTML report template).
- `action.yml` and `.github/workflows/`.

Lower priority:
- The individual checks under `tests/`. They read configuration and report it; a bug that only produces a wrong
  pass or fail is a correctness issue, not a vulnerability, unless it is caused by attacker-controlled tenant data
  making a check pass when it should fail.
- `build/` scripts, which only maintainers run.

Out of scope:
- `website/` (the documentation site) and `docs/`.
- Generated files under `powershell/internal/generated/`, `tests/eidsca/` and `tests/orca/`, except where a flaw in
  the generator in `build/` is the cause.
- The security of Microsoft 365 itself, and tenant misconfigurations that Maester is designed to report.

## How to exercise it

- The image has the module built to `/src/module/` and the source module at `/src/powershell/Maester.psd1`.
  `pwsh -c "Import-Module /src/powershell/Maester.psd1"` loads it.
- There is no tenant and no network during the scan. Mock the API layer instead: the unit tests in
  `powershell/tests/` mock `Invoke-MtGraphRequest` and the other service wrappers with Pester `Mock`; follow them to
  feed hostile tenant data into checks and the report. `./powershell/tests/pester.ps1` runs the whole suite.
- `Get-MtHtmlReport` turns a result object into the HTML report; results can be built by hand or taken from test
  fixtures.
- The report template source is in `report/src/` and is built with `npm run build` in `report/`.

## How we rate severity

- **Critical**: code execution on the machine running Maester, or theft of its access tokens or secrets, triggered by
  data a low-privileged tenant user, a remote site or a shared result file controls.
- **High**: script execution in the HTML report from tenant data or an imported result file; injection into CI
  workflows that exposes secrets; a check that an attacker can force to pass when it should fail by setting tenant
  data, hiding a real misconfiguration.
- **Medium**: tenant data that renders as a working link, remote image or spoofed content in the report, email or Teams
  message without script execution; path traversal in file output that needs an unusual operator setting.
- **Low**: denial of service of a run (a crash or hang from malformed data); information shown in the console or logs
  that the operator can already see.

## Reports and patches

- Include the input that triggers the issue (the tenant value, file or response) and the exact command to reproduce it
  with mocks.
- Patches should follow the existing style: PowerShell functions in `Verb-Noun.ps1` files, one function per file, and
  come with a Pester unit test in `powershell/tests/` that fails before the fix.

## Anything to leave alone

- Commands that run code the operator gave them on purpose (custom tests, `-Script` style parameters, the Exchange
  command map in `Get-MtExo`, which uses a fixed list of commands) are not injection.
- Permissions a check requests in its documentation, or the Graph scopes `Get-MtGraphScope` lists, are by design.
- Findings in third-party dependencies (npm packages, PowerShell Gallery modules) unless Maester uses them in an
  exploitable way.
