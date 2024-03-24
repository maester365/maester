<#
 .Synopsis
  Generates a formatted html report using the xml output from unit test frameworks like Pester.

 .Description
    The generated html is a single file that provides a visual representation of the test
    results with a summary view and click through of the details.

 .Example
    $pesterResults = Invoke-Pester -PassThru
    Export-MtHtmlReport -PesterResults $pesterResults -OutputHtmlPath ./testResults.html
#>

Function Export-MtHtmlReport {
    [CmdletBinding()]
    param(
        # The Pester test results returned from Invoke-Pester -PassThru
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [psobject] $PesterResults,
        # The path to the html file to be generated
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
        [string] $OutputHtmlPath
    )

    $json = ConvertTo-MtMaesterResults $PesterResults | ConvertTo-Json -Depth 3 -WarningAction Ignore

    $htmlFilePath = Join-Path -Path $PSScriptRoot -ChildPath '../assets/ReportTemplate.html'
    $templateHtml = Get-Content -Path $htmlFilePath -Raw

    # Insert the test results json into the template
    $insertLocationStart = $templateHtml.IndexOf("const testResults = {")
    $insertLocationEnd = $templateHtml.IndexOf("function App() {")

    $outputHtml = $templateHtml.Substring(0, $insertLocationStart)
    $outputHtml += "const testResults = $json;`n"
    $outputHtml += $templateHtml.Substring($insertLocationEnd)

    # Create the html file
    Out-File -FilePath $OutputHtmlPath -InputObject $outputHtml -Encoding UTF8
}