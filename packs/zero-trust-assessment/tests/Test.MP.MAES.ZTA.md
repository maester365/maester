Runs the [Microsoft Zero Trust Assessment](https://aka.ms/zerotrust/assessment) and reports each of its results in
the Maester report, with the assessment's own description, remediation steps and findings.

The assessment rates the tenant against Microsoft's Zero Trust guidance across the Identity, Devices, Network,
Data, Infrastructure, Security Operations and AI pillars. Each result is its own row, `MP.MAES.ZTA.<assessment test ID>`.

#### Running it

The pack is long-running and does not run by default. Run it with `Invoke-Maester -TestId MP.MAES.ZTA` or
`-IncludeLongRunning`. It reads a report the assessment already wrote when the `ZeroTrustAssessment.ReportPath`
setting names one; otherwise it runs the assessment, which needs the `ZeroTrustAssessment` module.

<!--- Results --->
%TestResult%
