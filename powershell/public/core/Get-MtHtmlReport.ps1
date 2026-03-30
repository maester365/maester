<#
 .Synopsis
  Generates a formatted html report using the MaesterResults object created by ConvertTo-MtMaesterResult

 .Description
    The generated html is a single file that provides a visual representation of the test
    results with a summary view and click through of the details.

    Supports both single-tenant results (from ConvertTo-MtMaesterResult) and multi-tenant
    results (from Merge-MtMaesterResult).

 .Example
    $pesterResults = Invoke-Pester -PassThru
    $maesterResults = ConvertTo-MtMaesterResult $pesterResults
    $output = Get-MtHtmlReport -MaesterResults $maesterResults
    $output | Out-File -FilePath $out.OutputHtmlFile -Encoding UTF8

    This example shows how to generate the html report and save it to a file by using Invoke-Pester

 .Example
    $maesterResults = Invoke-Maester -PassThru
    $output = Get-MtHtmlReport -MaesterResults $maesterResults
    $output | Out-File -FilePath $out.OutputHtmlFile -Encoding UTF8

    This example shows how to generate the html report and save it to a file by using Invoke-Maester

 .Example
    $result1 = Invoke-Maester -PassThru
    $result2 = Invoke-Maester -PassThru
    $merged = Merge-MtMaesterResult -MaesterResults @($result1, $result2)
    $output = Get-MtHtmlReport -MaesterResults $merged
    $output | Out-File -FilePath "MultiTenantReport.html" -Encoding UTF8

    This example shows how to generate a multi-tenant html report

.LINK
    https://maester.dev/docs/commands/Get-MtHtmlReport
#>
function Get-MtHtmlReport {
    [CmdletBinding()]
    param(
        # The Maester test results returned from `Invoke-Pester -PassThru | ConvertTo-MtMaesterResult`
        # or from `Merge-MtMaesterResult` for multi-tenant reports.
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject] $MaesterResults
    )

    # Use depth 7 for multi-tenant to handle: Tenants > Tests > ErrorRecord > nested objects
    $isMultiTenant = $MaesterResults.PSObject.Properties.Name -contains 'Tenants'
    $depth = if ($isMultiTenant) { 7 } else { 5 }

    Write-Verbose "Generating HTML report."
    $json = $MaesterResults | ConvertTo-Json -Depth $depth -WarningAction Ignore

    $htmlFilePath = Join-Path -Path $PSScriptRoot -ChildPath '../../assets/ReportTemplate.html'
    $templateHtml = Get-Content -Path $htmlFilePath -Raw

    # Insert the test results json into the template
    # Note: The minified output from Vite has no spaces around '=' so we use 'testResults={'
    $startMarker = 'testResults={'
    $endMarker = 'EndOfJson:"EndOfJson"}'
    $insertLocationStart = $templateHtml.IndexOf($startMarker)
    $insertLocationEnd = $templateHtml.IndexOf($endMarker)

    if ($insertLocationStart -lt 0) {
        throw "Could not find start marker '$startMarker' in the report template."
    }
    if ($insertLocationEnd -lt 0) {
        throw "Could not find end marker '$endMarker' in the report template."
    }

    $insertLocationEnd += $endMarker.Length

    $outputHtml = $templateHtml.Substring(0, $insertLocationStart)
    $outputHtml += "testResults=$json"
    $outputHtml += $templateHtml.Substring($insertLocationEnd)

    return $outputHtml
}
