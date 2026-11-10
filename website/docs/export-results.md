---
title: Exporting results
---

Maester supports exporting test results to CSV and Excel files. This is useful for sharing test results with others or for further analysis in a spreadsheet program.

Maester also lists the objects affected by each check, and redact user identities from any of the generated files.

## Exporting a markdown summary

To export a compact markdown summary that contains only the counters table, use `Invoke-Maester` with `-OutputMarkdownSummaryFile`.

```powershell
Invoke-Maester -OutputMarkdownSummaryFile "C:\path\to\results-summary.md"
```

This summary is useful for quick updates in issues, pull requests, and chat messages.

## Exporting results to CSV

To export test results to a CSV file, use the `Convert-MtResultsToFlatObject` command with the `-CsvFilePath` parameter. The following example exports test results to a CSV file:

```powershell
$results = Invoke-Maester -PassThru
Convert-MtResultsToFlatObject -InputObject $results -CsvFilePath "C:\path\to\results.csv"
```

## Exporting results to Excel

To export test results to an Excel file, use the `Convert-MtResultsToFlatObject` command with the `-ExcelFilePath` parameter.

:::note

The `Convert-MtResultsToFlatObject` command requires the `ImportExcel` module. You can install the module by running `Install-Module ImportExcel`.

:::

The following example exports test results to an Excel file:

```powershell
$results = Invoke-Maester -PassThru
Convert-MtResultsToFlatObject -InputObject $results -ExcelFilePath "C:\path\to\results.xlsx"
```

## Flattening results

To export just the test results without the test suite hierarchy, use the `-PassThru` parameter with the `Convert-MtResultsToFlatObject` command. The following example exports flattened test results.

```powershell
$results = Invoke-Maester -PassThru
Convert-MtResultsToFlatObject -InputObject $results -PassThru
```

## Affected objects

Maester can list the **affected objects**: the consolidated list of objects that the run
touched — Entra ID objects such as Conditional Access policies, users, groups and service
principals, tenant-level configuration surfaces, the Microsoft Graph resources that were read,
and external systems such as GitHub.

Maester collects them on every run:

```powershell
$results = Invoke-Maester -PassThru
$results.AffectedObjects | Where-Object Type -eq 'ConditionalAccessPolicy'
```

When a test recorded an object, the HTML report has an **Affected objects** page, with the checks that
passed or failed for each object and a link to open it in the admin portal. A run whose tests recorded
no objects has no such page.

Tests and packs can also describe an object with [`Add-MtAffectedObjectFact`](commands/Add-MtAffectedObjectFact.mdx):
its last sign-in, its permissions, its expired secrets. Those facts are shown when the object's row is expanded, and
each record lists them under `Facts`. See
[Adding facts about an object](writing-tests/formatting-test-results.md#adding-facts-about-an-object).

With `-OutputFolder`, the list is also written next to the other reports as
`<name>-affected-objects.json`, and `-ExportCsv` adds `<name>-affected-objects.csv`. Neither file is
written when the list is empty.

```powershell
Invoke-Maester -OutputFolder "C:\path\to\results" -ExportCsv
```

The list makes the report larger. To leave it out, use `-ExcludeAffectedObjects`. `-IncludeAffectedObjects`,
which turned collection on before Maester 3.0, still works and changes nothing.

Each object carries a `UniqueId` that is derived from its identity, so the same object keeps the
same id across runs and can be correlated between reports.

## Hiding user identities from reports

Reports that are shared beyond the security team often should not name individual users. Use
`-RedactUserIdentity` to replace user display names, user principal names and user object ids with the user's
`UniqueId` from the affected objects:

| Value | Effect |
| --- | --- |
| `None` (default) | No redaction. |
| `HtmlOnly` | Redact the html report only, so the machine readable exports keep the real identifiers for follow-up. |
| `AllOutputs` | Redact every generated output: html, json, markdown, markdown summary, csv, Excel and the affected objects json/csv. |

Use `AllOutputs` when any file besides the html report leaves the security team, for example as a
pipeline artifact or mail attachment.

```powershell
Invoke-Maester -OutputFolder "C:\path\to\results" -RedactUserIdentity AllOutputs
```

Redaction is driven by the affected objects, so `-RedactUserIdentity` collects them automatically.
They stay internal to the redaction step unless you also pass `-IncludeAffectedObjects`.

The same parameter is available on `Get-MtHtmlReport` when you generate the html report yourself.

:::caution

Redaction is best effort. Maester replaces the users in the affected objects, the account that
ran Maester, plus the user
principal names and object ids of every user it read from Microsoft Graph during the run (for
example the users named in data-driven test titles). Free text that names a person the run never
read is not detected, and display names are only replaced for users in the affected objects.

The replacement token is derived from the object's identity with an unsalted hash, so it is
pseudonymization rather than anonymization: anyone holding a list of candidate object ids or
user principal names can reverse it, and the same user produces the same token in every
tenant's report. Review a report before sharing it if the tenant has strict privacy
requirements.

:::
