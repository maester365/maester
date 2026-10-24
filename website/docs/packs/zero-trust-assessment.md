---
title: Zero Trust Assessment pack
sidebar_position: 4
description: Run Microsoft's Zero Trust Assessment from Maester and see each of its results in the Maester report.
---

# Zero Trust Assessment pack

This pack runs Microsoft's [Zero Trust Assessment](https://aka.ms/zerotrust/assessment) and shows each of its
results in the Maester report, next to Maester's own checks. It ships with Maester and does not run unless you
ask for it.

Each assessment result is one row, `ZTA.<assessment test ID>` (for example `ZTA.21770`), with the
assessment's title, risk level (as the severity), description, remediation steps and findings. Results are tagged
`ZeroTrust` and `ZeroTrust.<pillar>` (`ZeroTrust.Identity`, `ZeroTrust.Devices` and so on).

The pack's ID is `maester.zero-trust-assessment`. It needs no `Install-MtPack`: it is part of the Maester module,
and `Get-MtPack` lists it.

## Run it

Install the assessment's module once, connect Maester to the tenant, then name the pack:

```powershell
Install-Module ZeroTrustAssessment -Scope CurrentUser
Connect-Maester
Invoke-Maester -Pack ZTA -SkipBuiltIn    # only the Zero Trust Assessment
Invoke-Maester -Pack ZTA                 # Maester's tests and the assessment
```

You don't run `Connect-ZtAssessment` yourself. The assessment runs in a separate PowerShell process, which can't
use the sign-ins of your session, so Maester signs in there for you (see
[Let Maester run the assessment](#let-maester-run-the-assessment)). After an interactive `Connect-Maester` you
sign in a second time, in the browser, for the assessment. `Connect-Maester` is still needed: it tells the
assessment which tenant to sign in to, and the pack is skipped while Maester is not connected to Graph. If you
read a report you already have (below), you run `Connect-ZtAssessment` and `Invoke-ZtAssessment` yourself first.

The pack is a long-running test, so `Invoke-Maester` leaves it out unless you name it. These also run it:

```powershell
Invoke-Maester -TestId ZTA          # only the Zero Trust Assessment
Invoke-Maester -Suite ZTA              # the same
Invoke-Maester -IncludeLongRunning          # everything, including the assessment
```

The pack itself stays enabled, so naming it is enough; it is the long-running flag that keeps it out of a plain
`Invoke-Maester`. To remove it entirely, set `Packs: [{ "Id": "maester.zero-trust-assessment", "Enabled": false }]`.

To run it on every run, add it to `Selection.TestId` in `maester-config.json`, or set
`Selection.IncludeLongRunning` to `true`. Give it time with `Execution.LongRunningTimeoutSeconds`: the assessment
can take an hour or more on a large tenant.

The pack gets the assessment's results one of two ways.

### Read a report you already have (recommended in CI)

Run the assessment as its own step, then point Maester at the report it wrote:

```powershell
Install-Module ZeroTrustAssessment -Scope CurrentUser
Connect-ZtAssessment
Invoke-ZtAssessment -Path ./zt -NoBrowser
```

```json
{ "GlobalSettings": { "ZeroTrustAssessment.ReportPath": "./zt" } }
```

Then, in a new PowerShell session (the assessment's modules can't share one with Maester's), connect Maester to
the same tenant and run the pack:

```powershell
Connect-Maester
Invoke-Maester -Pack ZTA
```

`ZeroTrustAssessment.ReportPath` takes the report file (`ZeroTrustAssessmentReport.json`), the folder given to
`Invoke-ZtAssessment -Path`, or its `zt-export` folder. Maester refuses a report written for another tenant than the
one it is connected to, and one older than `ZeroTrustAssessment.MaxReportAgeDays` (7 by default; 0 turns the check
off).

### Let Maester run the assessment

Without `ZeroTrustAssessment.ReportPath`, Maester runs the assessment itself. Install the module first:

```powershell
Install-Module ZeroTrustAssessment -Scope CurrentUser
```

The assessment loads its own versions of the Microsoft Graph, Exchange Online and Az modules, which cannot share
a PowerShell session with the ones Maester has loaded. So Maester starts it in a separate `pwsh` process, which
signs in with `Connect-ZtAssessment`:

- It signs in to the tenant Maester is connected to.
- When Maester is connected to Graph app-only with a certificate, it uses the same app and certificate. The app
  needs the Graph application permissions that `Get-ZtGraphScope` lists.
- When Maester is connected app-only another way (a client secret, a managed identity or workload identity
  federation), the pack is skipped with the reason: the assessment signs in app-only only with a certificate. See
  [Run it in a pipeline](#run-it-in-a-pipeline).
- Otherwise it signs in interactively, so you sign in a second time. Without a browser, for example over SSH, set
  `ZeroTrustAssessment.Connect` to `{ "UseDeviceCode": true }`.

While it runs, what the assessment writes is shown live: in the full-screen dashboard of an interactive run it
scrolls in a box in the middle of the screen, under the phases of the run, and in other modes (CI, redirected
output, `-Verbosity Normal`) it is written to the console, indented. The assessment runs with `-ShowLog`, so it lists
the tests it runs, and its progress bars become one line at the bottom of the box that updates in place. Set
`ZeroTrustAssessment.ShowLog` to `false` for its shorter output.

The top of the box shows where the assessment is, read once a second from the progress the assessment keeps for
its own progress page and from the progress logs it writes in its output folder:

- the six stages of the assessment as a track (Export, Tests, Tenant info, Results, Report data, HTML report),
  with the step of the stage it is on, such as "Importing Data into Database";
- a bar of the exports or tests done of how many, the percentage, how many failed and are running, and the time
  left;
- each export or test that is running, with what it is doing and how long it has run, and the ones that finished,
  with their result and how long they took, listed the way the dashboard lists Maester's own tests (tests by
  their `ZTA.` ID and title);
- each export, database import or test that fails or times out, with its error. The box counts them.

The rest of the dashboard follows the assessment while it runs:

- the Results panel and the result blocks over the box count the assessment's results (passed, failed,
  investigate, skipped) as its tests finish;
- the assessment's pillars are listed where Maester's products usually are, each with a bar and its counts;
- the Pace graph next to the logo draws how long each export and test took, and the Slowest panel lists the
  slowest of them.

Outside the dashboard the stage is written when it changes, each export and test as it finishes with its result
and time, the counts at most every ten seconds, and each failure as it happens. This needs version 3.1 or later of the ZeroTrustAssessment module; with an earlier version the
box shows the log only.

The assessment's own report and raw export go to a temporary folder that Maester deletes after reading it, because
the export holds tenant data. Set `ZeroTrustAssessment.OutputPath` to keep them.

## Run it in a pipeline

In GitHub Actions, Azure DevOps or any other pipeline, nobody is there to sign in, so the assessment signs in
as a service principal. `Connect-ZtAssessment` signs in app-only only with a certificate, found by thumbprint in
the certificate store of the computer it runs on. A client secret, a managed identity or workload identity
federation (the OIDC sign-in in [Maester's GitHub guide](../monitoring/github.md)) is enough for Maester's own
tests but not for the assessment.

So the pipeline needs:

1. An app registration with a certificate. Give the app the Graph application permissions that
   `Get-ZtGraphScope` lists (run it after `Import-Module ZeroTrustAssessment`), plus Maester's own permissions if
   the same run includes Maester's tests. The assessment's Azure, Exchange Online, Security & Compliance and
   SharePoint tests need the app to have the roles the
   [Zero Trust Assessment documentation](https://aka.ms/zerotrust/assessment) lists for app-only sign-in; to
   leave those services out, set `ZeroTrustAssessment.Connect` to `{ "Service": ["Graph"] }`.
2. The certificate as a PFX file, saved base64-encoded in a pipeline secret with its password.
3. A step that adds the certificate to the current user's certificate store, connects Maester to Graph with it
   by thumbprint, and runs the pack. The child process finds the same certificate by its thumbprint.

A GitHub Actions workflow that does this on a schedule, with the secrets `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`,
`ZTA_CERTIFICATE` (the base64 PFX) and `ZTA_CERTIFICATE_PASSWORD`:

```yaml
name: Zero Trust Assessment
on:
  schedule:
    - cron: '0 3 * * 1'
  workflow_dispatch:

jobs:
  zero-trust:
    runs-on: ubuntu-latest
    timeout-minutes: 360
    steps:
      - uses: actions/checkout@v4

      - name: Run the Zero Trust Assessment with Maester
        shell: pwsh
        env:
          TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          CERTIFICATE: ${{ secrets.ZTA_CERTIFICATE }}
          CERTIFICATE_PASSWORD: ${{ secrets.ZTA_CERTIFICATE_PASSWORD }}
        run: |
          Install-Module Maester, ZeroTrustAssessment -Scope CurrentUser -Force

          # Add the certificate to the current user's store, where the assessment looks for it.
          $flags = 'PersistKeySet, Exportable'
          $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
              [Convert]::FromBase64String($env:CERTIFICATE), $env:CERTIFICATE_PASSWORD, $flags)
          $store = [System.Security.Cryptography.X509Certificates.X509Store]::new('My', 'CurrentUser')
          $store.Open('ReadWrite'); $store.Add($cert); $store.Close()

          Connect-MgGraph -ClientId $env:CLIENT_ID -TenantId $env:TENANT_ID -CertificateThumbprint $cert.Thumbprint -NoWelcome
          Invoke-Maester -Pack ZTA -NonInteractive -OutputFolder ./test-results

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: maester-zero-trust
          path: test-results
```

The assessment can take an hour or more on a large tenant: keep the job's `timeout-minutes` above that, and raise
`Execution.LongRunningTimeoutSeconds` in `maester-config.json` if Maester stops it first. On Windows runners the
same steps work in `pwsh`.

If the assessment runs somewhere else, or you'd rather keep the certificate out of the Maester step, run
`Connect-ZtAssessment -ClientId <app> -TenantId <tenant> -Certificate <thumbprint>` and
`Invoke-ZtAssessment -Path ./zt -NoBrowser` as their own step, then let Maester read the report with
`ZeroTrustAssessment.ReportPath` (see [Read a report you already have](#read-a-report-you-already-have-recommended-in-ci)).
Maester's step can then connect any way it likes, including OIDC, as long as it is the same tenant.

## The assessment's own report

The Maester report embeds the HTML report the assessment wrote, with its pillar dashboards and charts. Open it
with the **Zero Trust Assessment** button on the report's overview, under **Reports** in the left menu, or on any
ZTA result. It opens inside the Maester report, with an option to open it in a new browser tab, and works
offline, so the Maester report stays a single file to share.

The embedded report is compressed: a 10 MB assessment report adds about 2 MB to the Maester report. It is left
out when `ZeroTrustAssessment.EmbedReport` is `false`, when you read a report file that has no
`ZeroTrustAssessmentReport.html` beside it or one folder up, and when `Invoke-Maester -RedactUserIdentity` is
used, because Maester cannot redact the assessment's report.

## Settings

All settings go in `GlobalSettings` of `maester-config.json`.

| Setting | Default | What it does |
| --- | --- | --- |
| `ZeroTrustAssessment.ReportPath` | empty | Read this report instead of running the assessment. |
| `ZeroTrustAssessment.MaxReportAgeDays` | `7` | Refuse a report older than this. `0` turns the check off. |
| `ZeroTrustAssessment.EmbedReport` | `true` | Embed the assessment's own HTML report in the Maester report. |
| `ZeroTrustAssessment.OutputPath` | temporary | Where the assessment writes its report and export. Kept when set. |
| `ZeroTrustAssessment.Pillar` | `All` | Run one pillar only: `Identity`, `Devices`, `Network`, `Data`, `Infrastructure`, `SecOps` or `AI`. |
| `ZeroTrustAssessment.Tests` | all | Run only these assessment test IDs, for example `["21770", "21771"]`. |
| `ZeroTrustAssessment.Days` | `30` | Days of sign-in logs the assessment reads (1 to 30). |
| `ZeroTrustAssessment.ShowLog` | `true` | Run the assessment with `-ShowLog`, which lists the tests it runs in its live output. |
| `ZeroTrustAssessment.DisableTelemetry` | `true` | The assessment sends the tenant ID to Microsoft unless this is `true`. |
| `ZeroTrustAssessment.Connect` | none | Further `Connect-ZtAssessment` parameters, for example `{ "Service": ["Graph", "Azure"], "UseDeviceCode": true }`. |

`EmergencyAccessAccounts` is passed to the assessment as well, so its Conditional Access tests leave out the same
break-glass accounts as Maester's.

## How results map

| Assessment status | Maester result |
| --- | --- |
| Passed | Passed |
| Failed | Failed |
| Investigate | Investigate |
| Skipped | Skipped, with the assessment's reason |
| Error | Error |
| Planned | Not shown: the assessment has not built the test yet |

A test that writes several rows under one ID (the Defender for Cloud recommendations) gets one row each, with a
suffix made from the row's title so that it keeps its ID from run to run.

## Licence

The Zero Trust Assessment is © Microsoft Corporation and published under the
[MIT licence](https://github.com/microsoft/zerotrustassessment/blob/main/LICENSE). This pack does not include
its code: it runs the module you install, or reads the report it wrote.
