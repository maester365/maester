---
title: 📤 Exporting results
---

Maester supports exporting test results to CSV and Excel files. This is useful for sharing test results with others or for further analysis in a spreadsheet program.

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
