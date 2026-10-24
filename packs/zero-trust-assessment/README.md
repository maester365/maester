# Microsoft Zero Trust Assessment pack

This pack runs Microsoft's [Zero Trust Assessment](https://aka.ms/zerotrust/assessment) and shows each of its
results in the Maester report, next to Maester's own checks. It ships with Maester and does not run unless you
ask for it.

Each assessment result is one row, `ZTA.<assessment test ID>` (for example `ZTA.21770`), with the
assessment's title, risk level (as the severity), description, remediation steps and findings. Results are tagged
`ZeroTrust` and `ZeroTrust.<pillar>` (`ZeroTrust.Identity`, `ZeroTrust.Devices` and so on).

How to run it, its settings and how results map are on
[maester.dev/docs/packs/zero-trust-assessment](https://maester.dev/docs/packs/zero-trust-assessment).

## Maintaining the pack

`catalog.json` lists the assessment's tests, titles and ratings for the pack's listing. It is generated; do not
edit it. To move the pack to a new version of the module, run:

```powershell
./build/zta/Update-MtZtaCatalog.ps1 -SourcePath <ZeroTrustAssessment module folder or repository clone>
```

The live progress in Maester's output box depends on two things in the module, which a new version can change:
the `ZtAssessment.ProgressState` dictionary (`_stageName`, `_stageNumber`, `_totalStages`, `_totalItems`,
`_completedItems`, `_failedItems`, `_inProgressItems` and the `worker_*` entries) and the lines of
`zt-export/logs/<run>/1-export_progress.log`, `2-database_progress.log` and `3-test_progress.log`. When you move
the pack to a new version, run it once and check that the box still shows the stage and the counts.

The Zero Trust Assessment is © Microsoft Corporation and published under the
[MIT licence](https://github.com/microsoft/zerotrustassessment/blob/main/LICENSE). This pack does not include
its code: it runs the module you install, or reads the report it wrote.
