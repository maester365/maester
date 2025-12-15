---
title: 📤 Exporting results
---

Maester supports exporting test results to CSV and Excel files. This is useful for sharing test results with others or for further analysis in a spreadsheet program.

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
