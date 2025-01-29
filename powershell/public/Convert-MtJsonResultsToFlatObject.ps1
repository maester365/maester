function Convert-MtJsonResultsToFlatObject {
    <#
    .SYNOPSIS
    Convert Maester test results from JSON to a flattened object that can be exported to CSV or Excel.

    .DESCRIPTION
    Convert Maester test results from JSON to a flattened object that can be exported to CSV or Excel. This function exports
    the data to a CSV file by default, but can also export to an Excel file if the ImportExcel module is installed.

    .PARAMETER JsonFilePath
    The path of the file containing the Maester test results in JSON format.

    .PARAMETER CsvFilePath
    The path of the file to export CSV data to.

    .PARAMETER ExcelFilePath
    The path of the file to export an Excel worksheet to.

    .PARAMETER ExportExcel
    Export the flattened object to an Excel workbook using the ImportExcel module.

    .PARAMETER Passthru
    Return the flattened object to the pipeline.

    .EXAMPLE
    Convert-MtJsonResultsToFlatObject -JsonFilePath 'C:\path\to\results.json'

    Convert the Maester test results from JSON to a flattened object and then export that object to a CSV file.

    .EXAMPLE
    Convert-MtJsonResultsToFlatObject -JsonFilePath 'C:\path\to\results.json' -ExportExcel

    Convert the Maester test results from JSON to a flattened object and then export that object to an Excel file.

    .OUTPUTS
    System.Collections.Generic.List[PSObject]

    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PSObject]])]
    param (
        # The path to the JSON file containing the Maester test results.
        [Parameter(Mandatory, Position = 0, HelpMessage = 'The path to the JSON file containing the Maester test results.')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
        [string]$JsonFilePath,

        # The path to the CSV file to which the Maester test results will be exported.
        [Parameter(HelpMessage = 'The path to the CSV file to which the Maester test results will be exported.')]
        [string]$CsvFilePath = "$($JsonFilePath -replace '\.json$', '.csv')",

        # The path to the Excel file to which the Maester test results will be exported.
        [Parameter(HelpMessage = 'The path to the Excel file to which the Maester test results will be exported.')]
        [string]$ExcelFilePath = "$($JsonFilePath -replace '\.json$', '.xlsx')",

        # Export the Maester test results to an Excel file.
        [Parameter()]
        [switch]
        $ExportExcel,

        # Return the flattened object to the pipeline.
        [Parameter()]
        [switch]
        $Passthru
    )

    #region ReplacementStrings
    # Replacement strings for emoji characters and apostrophes that do not translate well to CSV files.
    $ReplacementStrings = @{
        'âŒ'       = ''
        'âž¡ï¸'    = ''
        'âœ…'       = ''
        'youâ€™re'  = 'you are'
        'arenâ€™nt' = 'are not'
    } ; [void]$ReplacementStrings # Not Used Yet
    #endregion ReplacementStrings

    $MaesterResults = New-Object System.Collections.Generic.List[PSObject]

    $JsonData = (Get-Content -Path $JsonFilePath | ConvertFrom-Json).Tests
    $JsonData | ForEach-Object {
        $MaesterResults.Add([PSCustomObject]@{
                Name           = $_.Name
                Tag            = $_.Tag -join ', '
                Block          = $_.Block
                Result         = $_.Result
                Description    = $_.ResultDetail.TestDescription
                ResultDetail   = "$($_.ResultDetail.TestResult -replace '(?s)(.*?)#### Impacted resources.*?#### Remediation actions:','$1#### Remediation actions:')"
                TestSkipped    = $_.ResultDetail.TestSkipped
                SkippedReason  = $_.ResultDetail.SkippedReason
                ErrorMessage   = $_.ErrorRecord.Exception.Message
                HelpUrl        = $_.HelpUrl
                TestScriptFile = [System.IO.Path]::GetFileName($_.ScriptBlockFile)
            })
    }

    try {
        $MaesterResults | Export-Csv -Path $CsvFilePath -UseQuotes Always -NoTypeInformation
    } catch {
        Write-Error "Failed to export the Maester test results to a CSV file. $_"
    }

    if ($ExportExcel.IsPresent) {
        try {
            $MaesterResults | Export-Excel -Path $ExcelFilePath -FreezeTopRow -AutoFilter -BoldTopRow -WorksheetName 'Results'
        } catch {
            Write-Error "Failed to export the Maester test results to an Excel file. $_"
        }
    }

    if ($Passthru.IsPresent) {
        $MaesterResults
    }
} #end function Convert-MtJsonResultsToFlatObject
