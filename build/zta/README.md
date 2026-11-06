# Maintaining the Zero Trust Assessment pack

The pack is in [`packs/zero-trust-assessment`](../../packs/zero-trust-assessment).

`catalog.json` lists the assessment's tests, titles and ratings for the pack's listing, and each test's
`Description` and `Remediation` from its `Test-Assessment.<id>.md` (Microsoft's text, MIT licence), which
maester.dev shows on the test's page. It is generated; do not edit it.

`taxonomy.json` is kept by hand. The assessment does not say which Maester product, feature and area a test is
about, or which ATT&CK techniques its control addresses, so this file does, for each assessment test ID:
`Product`, `Feature`, `Area`, optional `RelatedProduct`, `Mitre` (technique IDs, or `None`) and `AlsoCheckedBy`
(built-in Maester tests that check the same setting). Choose the values with the
[attribute rubric](../../website/docs/writing-tests/attribute-rubric.md). The catalog build copies them into
`catalog.json`, and the pack sets them on each result, so the report and maester.dev show an assessment result
under its product. The unit tests fail when a test of the catalog is not mapped, or a value is not in the taxonomy.

To move the pack to a new version of the module, run:

```powershell
./build/zta/Update-MtZtaCatalog.ps1 -SourcePath <ZeroTrustAssessment module folder or repository clone>
```

The live progress in Maester's output box depends on two things in the module, which a new version can change:
the `ZtAssessment.ProgressState` dictionary (`_stageName`, `_stageNumber`, `_totalStages`, `_totalItems`,
`_completedItems`, `_failedItems`, `_inProgressItems` and the `worker_*` entries) and the lines of
`zt-export/logs/<run>/1-export_progress.log`, `2-database_progress.log` and `3-test_progress.log`. When you move
the pack to a new version, run it once and check that the box still shows the stage and the counts. Map the
tests the new version adds in `taxonomy.json` (the script warns about each one), remove the ones it dropped, and
run the script again.
