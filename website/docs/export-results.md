---
title: 📤 Exporting results
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

:::info

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

Collection is opt-in, because it makes the report larger. Use `-IncludeAssetInventory`:

```powershell
$results = Invoke-Maester -IncludeAssetInventory -PassThru
$results.AssetInventory | Where-Object Type -eq 'ConditionalAccessPolicy'
```

The HTML report then has an **Affected objects** page, with the checks that passed or failed for
each object and a link to open it in the admin portal. Without the switch, nothing is collected and
the page is not offered.

When you also use `-OutputFolder`, the list is written next to the other reports as
`<name>-assets.json`. Adding `-ExportCsv` also writes `<name>-assets.csv`.

```powershell
Invoke-Maester -IncludeAssetInventory -OutputFolder "C:\path\to\results" -ExportCsv
```

Each asset carries a `UniqueId` that is derived from its identity, so the same object keeps the
same id across runs and can be correlated between reports.

## Hiding user identities from reports

Reports that are shared beyond the security team often should not name individual users. Use
`-RedactUserIdentity` to replace user display names, user principal names and user object ids with the user's
`UniqueId` from the affected objects:

| Value | Effect |
| --- | --- |
| `None` (default) | No redaction. |
| `HtmlOnly` | Redact the html report only, so the machine readable exports keep the real identifiers for follow-up. |
| `AllOutputs` | Redact every generated output: html, json, markdown, markdown summary, csv, Excel and the asset json/csv. |

Use `AllOutputs` when any file besides the html report leaves the security team, for example as a
pipeline artifact or mail attachment.

```powershell
Invoke-Maester -OutputFolder "C:\path\to\results" -RedactUserIdentity AllOutputs
```

Redaction is driven by the affected objects, so `-RedactUserIdentity` collects them automatically.
They stay internal to the redaction step unless you also pass `-IncludeAssetInventory`.

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
