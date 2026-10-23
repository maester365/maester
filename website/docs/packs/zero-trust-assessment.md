---
title: Zero Trust Assessment pack
sidebar_position: 4
description: Run Microsoft's Zero Trust Assessment from Maester and see each of its results in the Maester report.
---

# Zero Trust Assessment pack

This pack runs Microsoft's [Zero Trust Assessment](https://aka.ms/zerotrust/assessment) and shows each of its
results in the Maester report, next to Maester's own checks. It ships with Maester and does not run unless you
ask for it.

Each assessment result is one row, `MP.ZTA.<assessment test ID>` (for example `MP.ZTA.21770`), with the
assessment's title, risk level (as the severity), description, remediation steps and findings. Results are tagged
`ZeroTrust` and `ZeroTrust.<pillar>` (`ZeroTrust.Identity`, `ZeroTrust.Devices` and so on).

The pack's ID is `maester.zero-trust-assessment`. It needs no `Install-MtPack`: it is part of the Maester module,
and `Get-MtPack` lists it.

## Run it

The pack is a long-running test, so `Invoke-Maester` leaves it out unless you name it:

```powershell
Invoke-Maester -TestId MP.ZTA          # only the Zero Trust Assessment
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
- Otherwise it signs in interactively, so you sign in a second time.

The assessment's own report and raw export go to a temporary folder that Maester deletes after reading it, because
the export holds tenant data. Set `ZeroTrustAssessment.OutputPath` to keep them.

## Settings

All settings go in `GlobalSettings` of `maester-config.json`.

| Setting | Default | What it does |
| --- | --- | --- |
| `ZeroTrustAssessment.ReportPath` | empty | Read this report instead of running the assessment. |
| `ZeroTrustAssessment.MaxReportAgeDays` | `7` | Refuse a report older than this. `0` turns the check off. |
| `ZeroTrustAssessment.OutputPath` | temporary | Where the assessment writes its report and export. Kept when set. |
| `ZeroTrustAssessment.Pillar` | `All` | Run one pillar only: `Identity`, `Devices`, `Network`, `Data`, `Infrastructure`, `SecOps` or `AI`. |
| `ZeroTrustAssessment.Tests` | all | Run only these assessment test IDs, for example `["21770", "21771"]`. |
| `ZeroTrustAssessment.Days` | `30` | Days of sign-in logs the assessment reads (1 to 30). |
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
