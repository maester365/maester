function Convert-MtJsonResultsToFlatObject {
    <#
    .SYNOPSIS
    Convert Maester test results from JSON to a flattened object that can be exported to CSV or Excel.

    .DESCRIPTION
    Convert Maester test results from JSON to a flattened object that can be exported to CSV or Excel. This function exports
    the data to a CSV file by default, but can also export to an Excel file if the ImportExcel module is installed.

    .PARAMETER JsonFilePath
    The path of the file containing the Maester test results in JSON format.

    .PARAMETER ExportCsv
    Export the flattened object to a CSV file.

    .PARAMETER ExportExcel
    Export the flattened object to an Excel workbook using the ImportExcel module.

    .PARAMETER CsvFilePath
    The path of the file to export CSV data to.

    .PARAMETER ExcelFilePath
    The path of the file to export an Excel worksheet to.

    .PARAMETER Force
    Force the export to a CSV/XLSX file even if the file already exists.

    .PARAMETER Passthru
    Return the flattened object to the pipeline.

    .EXAMPLE
    Convert-MtJsonResultsToFlatObject -JsonFilePath 'C:\path\to\results.json'

    Convert the Maester test results from JSON to a flattened object that is returned to the pipeline.

    .EXAMPLE
    Convert-MtJsonResultsToFlatObject -JsonFilePath 'C:\path\to\results.json' -ExportExcel

    Convert the Maester test results from JSON to a flattened object and then export that object to an Excel file.

    .OUTPUTS
    System.Collections.Generic.List[PSObject]

    .NOTES
    Due to limitations in CSV files and Excel cells, the ResultDetails property is limited to 30000 characters. If the
    test result details are longer than this, that section will be truncated and a notification will be included in its
    place. This is most likely to happen when details about a large number of users is included in the result details.
    The full details are still available in the JSON file and the HTML report.
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

        # Export the Maester test results to a CSV file.
        [Parameter()]
        [switch]
        $ExportCsv,

        # Export the Maester test results to an Excel file.
        [Parameter()]
        [switch]
        $ExportExcel,

        # Force the export to a CSV/XLSX file even if the file already exists.
        [Parameter()]
        [switch]
        $Force,

        # Return the flattened object to the pipeline.
        [Parameter()]
        [switch]
        $Passthru
    )

    begin {
        # Check for an existing CSV file.
        if ($CsvFilePath -and (Test-Path -Path $CsvFilePath -PathType Leaf) -and -not $Force.IsPresent) {
            throw "The specified CSV file path '$CsvFilePath' already exists. Use -Force if you want to overwrite this file."
        }

        # Check for an existing Excel file.
        if ($ExcelFilePath -and (Test-Path -Path $ExcelFilePath -PathType Leaf) -and -not $Force.IsPresent) {
            throw "The specified Excel file path '$ExcelFilePath' already exists. Use -Force if you want to overwrite this file."
        }

        # Replacement strings for emoji characters and apostrophes that do not translate well to CSV files.
        [hashtable]$ReplacementStrings = @{
            'âŒ'       = ''
            'âž¡ï¸'    = ''
            'âœ…'       = ''
            'youâ€™re'  = 'you are'
            'arenâ€™nt' = 'are not'
        } ; [void]$ReplacementStrings # Not Used Yet
        [string]$TruncationFYI = 'NOTE: DETAILS ARE TRUNCATED DUE TO FIELD SIZE LIMITATIONS. PLEASE SEE THE HTML REPORT FOR FULL DETAILS.'

        $MaesterResults = New-Object System.Collections.Generic.List[PSObject]

        $JsonData = (Get-Content -Path $JsonFilePath | ConvertFrom-Json).Tests
    } #end begin

    process {
        $JsonData | ForEach-Object {

            # Truncate the ResultDetail.TestResult data if it is longer than 30000 characters.
            if ($_.ResultDetail.TestResult.Length -gt 30000) {
                $TestResultDetail = "$TruncationFYI`n`n$($TestResultDetail -replace '(?s)(.*?)#### Impacted resources.*?#### Remediation actions:','$1#### Remediation actions:')"
            } else {
                $TestResultDetail = $_.ResultDetail.TestResult
            }

            # Add the flattened object to the MaesterResults list.
            $MaesterResults.Add([PSCustomObject]@{
                    Name           = $_.Name
                    Tag            = $_.Tag -join ', '
                    Block          = $_.Block
                    Result         = $_.Result
                    Description    = $_.ResultDetail.TestDescription
                    ResultDetail   = $TestResultDetail
                    TestSkipped    = $_.ResultDetail.TestSkipped
                    SkippedReason  = $_.ResultDetail.SkippedReason
                    ErrorMessage   = $_.ErrorRecord.Exception.Message
                    HelpUrl        = $_.HelpUrl
                    TestScriptFile = [System.IO.Path]::GetFileName($_.ScriptBlockFile)
                })
        }

        # Export the MaesterResults list to a CSV if requested.
        if ($ExportCsv.IsPresent) {
            try {
                $MaesterResults | Export-Csv -Path $CsvFilePath -UseQuotes Always -NoTypeInformation
                Write-Information "Exported the Maester test results to '$CsvFilePath'." -InformationAction Continue
            } catch {
                Write-Error "Failed to export the Maester test results to a CSV file. $_"
            }
        }

        # Export the MaesterResults list to an Excel file if requested.
        if ($ExportExcel.IsPresent) {
            try {
                $MaesterResults | Export-Excel -Path $ExcelFilePath -FreezeTopRow -AutoFilter -BoldTopRow -WorksheetName 'Results'
                Write-Information "Exported the Maester test results to '$ExcelFilePath'." -InformationAction Continue
            } catch [System.Management.Automation.CommandNotFoundException] {
                Write-Error "The ImportExcel module is required to export the Maester test results to an Excel file. Install the module using ``Import-Module -Name 'ImportExcel'`` and try again."

            } catch {
                Write-Error "Failed to export the Maester test results to an Excel file. $_"
            }
        }
    }

    end {
        # Return the flattened object to the pipeline if requested or if no export is requested.
        if ($Passthru.IsPresent -or (-not $ExportCsv.IsPresent -and -not $ExportExcel.IsPresent)) {
            $MaesterResults
        }
    }

} #end function Convert-MtJsonResultsToFlatObject
