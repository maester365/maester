function Convert-MtResultsToFlatObject {
    <#
    .SYNOPSIS
    Convert Maester test results to a flattened object that can be exported to CSV or Excel.

    .DESCRIPTION
    Convert Maester test results to a flattened object that can be exported to CSV or Excel. This function exports
    the data to a CSV file by default, but can also export to an Excel file if the ImportExcel module is installed.

    The function also supports reading Maester test results from a JSON file and exporting the flattened object to a CSV.

    .PARAMETER InputObject
    Use the Maester test results from the pipeline or as an input object (JSON).

    .PARAMETER JsonFilePath
    The path of the file containing the Maester test results in JSON format.

    .PARAMETER ExportCsv
    Export the flattened object to a CSV file.

    .PARAMETER CsvFilePath
    The path of the file to export CSV data to.

    .PARAMETER ExportExcel
    Export the flattened object to an Excel workbook using the ImportExcel module.

    .PARAMETER ExcelFilePath
    The path of the file to export an Excel worksheet to.

    .PARAMETER Force
    Force the export to a CSV/XLSX file even if the file already exists.

    .PARAMETER PassThru
    Return the flattened object to the pipeline.

    .EXAMPLE
    Convert-MtJsonResultsToFlatObject -JsonFilePath 'C:\path\to\results.json'

    Convert the Maester test results in C:\path\to\results.json to a flattened object that is then returned to the pipeline.

    .EXAMPLE
    Convert-MtJsonResultsToFlatObject -JsonFilePath 'C:\path\to\results.json' -ExportExcel

    Convert the Maester test results in C:\path\to\results.json to a flattened object, and then export that object to an Excel file (C:\path\to\results.xlsx). Requires the ImportExcel module.

    .EXAMPLE
    Convert-MtJsonResultsToFlatObject -JsonFilePath 'C:\path\to\results.json' -ExportCsv -CsvFilePath 'C:\path\to\results.csv'

    Convert the Maester test results in C:\path\to\results.json to a flattened object, and then export that object to C:\path\to\results.csv.

    .OUTPUTS
    System.Collections.Generic.List[PSObject]

    .LINK
    https://maester.dev/docs/commands/Convert-MtResultsToFlatObject

    .NOTES
    Due to limitations in CSV files and Excel cells, the ResultDetails property is limited to 30000 characters. If the
    test result details are longer than this, that section will be truncated and a notification will be included in its
    place. This is most likely to happen when details about a large number of users is included in the result details.
    The full details are still available in the JSON file and the HTML report.
    #>
    [CmdletBinding(DefaultParameterSetName = 'FromFile')]
    [OutputType([System.Collections.Generic.List[PSObject]])]
    param (
        # The Maester test results passed from the pipeline using `Invoke-Maester -PassThru` or as an input object.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'FromInputObject')]
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'CSV')]
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'XLSX')]
        [Alias('MaesterResults')]
        [ValidateNotNullOrEmpty()]
        [psobject] $InputObject,

        # The path to the JSON file containing the Maester test results.
        [Parameter(Mandatory, Position = 0, HelpMessage = 'The path to the JSON file containing the Maester test results.', ParameterSetName = 'FromFile')]
        [Parameter(Mandatory, Position = 0, HelpMessage = 'The path to the JSON file containing the Maester test results.', ParameterSetName = 'CSV')]
        [Parameter(Mandatory, Position = 0, HelpMessage = 'The path to the JSON file containing the Maester test results.', ParameterSetName = 'XLSX')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
        [string] $JsonFilePath,

        # Export the results to a CSV file.
        [Parameter(HelpMessage = 'Export the results to a CSV file.')]
        [switch] $ExportCsv,

        # Export the results to an Excel file.
        [Parameter(HelpMessage = 'Export the results to an Excel file.')]
        [switch] $ExportExcel,

        # The path to the CSV file to which the Maester test results will be exported.
        [Parameter(HelpMessage = 'Optional when JsonFilePath is provided. The path to the CSV file to which the Maester test results will be exported.', ParameterSetName = 'CSV')]
        [Parameter(HelpMessage = 'Optional when JsonFilePath is provided. The path to the CSV file to which the Maester test results will be exported.', ParameterSetName = 'FromInputObject')]
        [Parameter(HelpMessage = 'Optional when JsonFilePath is provided. The path to the CSV file to which the Maester test results will be exported.', ParameterSetName = 'FromFile')]
        [string] $CsvFilePath = "$($JsonFilePath -replace '\.json$', '.csv')",

        # The path to the Excel file to which the Maester test results will be exported.
        [Parameter(HelpMessage = 'Optional when JsonFilePath is provided. The path to the Excel file to which the Maester test results will be exported.', ParameterSetName = 'XLSX')]
        [Parameter(HelpMessage = 'Optional when JsonFilePath is provided. The path to the Excel file to which the Maester test results will be exported.', ParameterSetName = 'FromInputObject')]
        [Parameter(HelpMessage = 'Optional when JsonFilePath is provided. The path to the Excel file to which the Maester test results will be exported.', ParameterSetName = 'FromFile')]
        [string]$ExcelFilePath = "$($JsonFilePath -replace '\.json$', '.xlsx')",

        # Force the export to a CSV/XLSX file even if the file already exists.
        [Parameter(ParameterSetName = 'FromInputObject', HelpMessage = 'Force the export to a CSV/XLSX file even if the file already exists.')]
        [Parameter(ParameterSetName = 'FromFile', HelpMessage = 'Force the export to a CSV/XLSX file even if the file already exists.')]
        [Parameter(ParameterSetName = 'CSV', HelpMessage = 'Force the export to a CSV file even if the file already exists.')]
        [Parameter(ParameterSetName = 'XLSX', HelpMessage = 'Force the export to an Excel file even if the file already exists.')]
        [switch]
        $Force,

        # Return the flattened object to the pipeline.
        [Parameter(ParameterSetName = 'FromInputObject', HelpMessage = 'Return the flattened object to the pipeline.')]
        [Parameter(ParameterSetName = 'FromFile', HelpMessage = 'Return the flattened object to the pipeline.')]
        [Parameter(ParameterSetName = 'CSV', HelpMessage = 'Return the flattened object to the pipeline.')]
        [Parameter(ParameterSetName = 'XLSX', HelpMessage = 'Return the flattened object to the pipeline.')]
        [switch]
        $PassThru
    )

    begin {

        # Check for an existing CSV file with the same name.
        if ( ($PSBoundParameters.ContainsKey('CsvFilePath') -or $ExportCsv.IsPresent ) -and (Test-Path -Path $CsvFilePath -PathType Leaf) -and -not $Force.IsPresent) {
            throw "The specified CSV file path '$CsvFilePath' already exists. Use -Force if you want to overwrite this file or specify a new filename."
        }

        # Check for an existing Excel file with the same name.
        if ( ($PSBoundParameters.ContainsKey('ExcelFilePath') -or $ExportExcel.IsPresent ) -and (Test-Path -Path $ExcelFilePath -PathType Leaf) -and -not $Force.IsPresent) {
            throw "The specified Excel file path '$ExcelFilePath' already exists. Use -Force if you want to overwrite this file or specify a new filename."
        }

        [string]$TruncationFYI = 'NOTE: DETAILS ARE TRUNCATED DUE TO FIELD SIZE LIMITATIONS. PLEASE SEE THE HTML REPORT FOR FULL DETAILS.'

        if ($PSCmdlet.ParameterSetName -eq 'FromInputObject') {
            $JsonData = $InputObject.Tests
        }

        if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
            $JsonData = (Get-Content -Path $JsonFilePath | ConvertFrom-Json).Tests
        }

        $FlattenedResults = New-Object System.Collections.Generic.List[PSObject]

    } #end begin

    process {
        $JsonData | ForEach-Object {

            # Truncate the ResultDetail.TestResult data if it is longer than 30000 characters.
            if ($_.ResultDetail.TestResult.Length -gt 30000) {
                Write-Verbose -Message "Truncating the ResultDetail.TestResult data for test '$($_.Name)' to 30000 characters." -Verbose
                $TestResultDetail = "$TruncationFYI`n`n$($TestResultDetail -replace '(?s)(.*?)#### Impacted resources.*?#### Remediation actions:','$1#### Remediation actions:')"
            } else {
                $TestResultDetail = $_.ResultDetail.TestResult
            }

            # Add the flattened object to the FlattenedResults list.
            $FlattenedResults.Add([PSCustomObject]@{
                    ID             = $_.ID
                    Title          = $_.Title
                    Result         = $_.Result
                    Severity       = $_.Severity
                    Tag            = $_.Tag -join ', '
                    Block          = $_.Block
                    Duration       = $_.Duration
                    Description    = $_.ResultDetail.TestDescription
                    ResultDetail   = $TestResultDetail
                    TestSkipped    = $_.ResultDetail.TestSkipped
                    SkippedReason  = $_.ResultDetail.SkippedReason
                    ErrorMessage   = $_.ErrorRecord.Exception.Message
                    Name           = $_.Name
                    HelpUrl        = $_.HelpUrl
                    TestScriptFile = [System.IO.Path]::GetFileName($_.ScriptBlockFile)
                })
        }

        # Export the FlattenedResults list to a CSV if requested.
        if ($ExportCsv.IsPresent -or $PSBoundParameters.ContainsKey('CsvFilePath')) {

            # Warn if the specified file path ends with the wrong extension.
            if ($CsvFilePath -match '\.xlsx$') {
                Write-Output ''
                Write-Warning -Message 'You are exporting a CSV file, but the file path ends with the .XLSX extension. Please rename with the proper extension or use the ''-ExcelFilePath'' parameter if you want an Excel file.' -WarningAction Continue
            }

            try {
                $FlattenedResults | Export-Csv -Path $CsvFilePath -UseQuotes Always -Encoding utf8BOM -NoTypeInformation
                Write-Verbose "Exported the Maester test results to '$CsvFilePath'." -InformationAction Continue
            } catch {
                Write-Error "Failed to export the Maester test results to a CSV file. $_"
            }
        }

        # Export the FlattenedResults list to an Excel file if requested.
        if ($ExportExcel.IsPresent -or $PSBoundParameters.ContainsKey('ExcelFilePath')) {

            # Warn if the specified file path ends with the wrong extension.
            if ($ExcelFilePath -match '\.csv$') {
                Write-Output ''
                Write-Warning -Message 'You are exporting an Excel file, but the file path ends with the .CSV extension. Please rename with the proper extension or use the ''-CsvFilePath'' parameter if you want a CSV file.' -WarningAction Continue
            }

            try {
                $FlattenedResults | Export-Excel -Path $ExcelFilePath -FreezeTopRow -AutoFilter -BoldTopRow -WorksheetName 'Results'
                Write-Verbose "Exported the Maester test results to '$ExcelFilePath'." -InformationAction Continue
            } catch [System.Management.Automation.CommandNotFoundException] {
                Write-Error "The ImportExcel module is required to export the Maester test results to an Excel file. Install the module using ``Import-Module -Name 'ImportExcel'`` and try again."

            } catch {
                Write-Error "Failed to export the Maester test results to an Excel file. $_"
            }
        }
    }

    end {
        # Return the flattened object to the pipeline if requested or if no export is requested.
        if ($PassThru.IsPresent -or (-not $ExcelFilePath -and -not $CsvFilePath)) {
            $FlattenedResults
        }
    }

} #end function Convert-MtResultsToFlatObject
