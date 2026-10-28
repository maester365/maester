# Maintaining the Zero Trust Assessment pack

The pack is in [`packs/zero-trust-assessment`](../../packs/zero-trust-assessment).

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
