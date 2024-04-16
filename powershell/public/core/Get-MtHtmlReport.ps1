<#
 .Synopsis
  Generates a formatted html report using the MaesterResults object created by ConvertTo-MtMaesterResult

 .Description
    The generated html is a single file that provides a visual representation of the test
    results with a summary view and click through of the details.

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
#>

Function Get-MtHtmlReport {
    [CmdletBinding()]
    param(
        # The Maester test results returned from `Invoke-Pester -PassThru | ConvertTo-MtMaesterResult`
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject] $MaesterResults
    )

    $json = $MaesterResults | ConvertTo-Json -Depth 3 -WarningAction Ignore

    $htmlFilePath = Join-Path -Path $PSScriptRoot -ChildPath '../../assets/ReportTemplate.html'
    $templateHtml = Get-Content -Path $htmlFilePath -Raw

    # Insert the test results json into the template
    $insertLocationStart = $templateHtml.IndexOf("const testResults = {")
    $insertLocationEnd = $templateHtml.IndexOf("function App() {")

    $outputHtml = $templateHtml.Substring(0, $insertLocationStart)
    $outputHtml += "const testResults = $json;`n"
    $outputHtml += $templateHtml.Substring($insertLocationEnd)

    return $outputHtml
}