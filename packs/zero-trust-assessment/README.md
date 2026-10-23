# Microsoft Zero Trust Assessment pack

This pack runs Microsoft's [Zero Trust Assessment](https://aka.ms/zerotrust/assessment) and shows each of its
results in the Maester report, next to Maester's own checks. It ships with Maester and does not run unless you
ask for it.

Each assessment result is one row, `MP.ZTA.<assessment test ID>` (for example `MP.ZTA.21770`), with the
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

The Zero Trust Assessment is © Microsoft Corporation and published under the
[MIT licence](https://github.com/microsoft/zerotrustassessment/blob/main/LICENSE). This pack does not include
its code: it runs the module you install, or reads the report it wrote.
