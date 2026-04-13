function Get-MtHtmlReport {
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
    [CmdletBinding()]
    param(
        # The Maester test results returned from `Invoke-Pester -PassThru | ConvertTo-MtMaesterResult`
        # or from `Merge-MtMaesterResult` for multi-tenant reports.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [psobject] $MaesterResults
    )

    # Use depth 7 for multi-tenant to handle: Tenants > Tests > ErrorRecord > nested objects
    $isMultiTenant = $MaesterResults.PSObject.Properties.Name -contains 'Tenants'
    $depth = if ($isMultiTenant) { 7 } else { 5 }

    Write-Verbose "Generating HTML report."
    $json = $MaesterResults | ConvertTo-Json -Depth $depth -Compress -WarningAction Ignore

    $htmlFilePath = Join-Path -Path $PSScriptRoot -ChildPath '../../assets/ReportTemplate.html'
    $templateHtml = Get-Content -Path $htmlFilePath -Raw

    # Find the LAST end marker (multi-tenant templates have one per tenant in the sample data)
    # Support both backtick (newer Vite/Rolldown) and double-quote (older Vite) formats
    $endMarkerBacktick = 'EndOfJson:`EndOfJson`}'
    $endMarkerDoubleQuote = 'EndOfJson:"EndOfJson"}'
    $insertLocationEnd = $templateHtml.LastIndexOf($endMarkerBacktick)
    $endMarkerLength = $endMarkerBacktick.Length

    if ($insertLocationEnd -lt 0) {
        $insertLocationEnd = $templateHtml.LastIndexOf($endMarkerDoubleQuote)
        $endMarkerLength = $endMarkerDoubleQuote.Length
    }

    if ($insertLocationEnd -lt 0) {
        throw "Could not find EndOfJson marker in the report template."
    }

    $insertLocationEnd += $endMarkerLength

    # Find the start marker: try classic 'testResults=' first, then scan for minified format
    $startMarker = 'testResults='
    $insertLocationStart = $templateHtml.IndexOf($startMarker)

    if ($insertLocationStart -ge 0) {
        # Classic format: testResults={...}
        Write-Verbose "Found classic marker: testResults="
    } else {
        # Newer minified format: var xx={Tenants:... or var xx={Result:...
        $searchRegion = $templateHtml.Substring(0, $insertLocationEnd)
        $dataStartPatterns = @('={Tenants:[', '={Result:', '={Result:`')
        $insertLocationStart = -1

        foreach ($pattern in $dataStartPatterns) {
            $pos = $searchRegion.LastIndexOf($pattern)
            if ($pos -ge 0) {
                $insertLocationStart = $pos + 1
                Write-Verbose "Found minified data pattern '$pattern' at position $pos"
                break
            }
        }

        if ($insertLocationStart -lt 0) {
            throw "Could not find test results data object in the report template."
        }
    }

    # Build the output: everything before the data + our JSON + everything after
    $outputHtml = $templateHtml.Substring(0, $insertLocationStart)
    if ($templateHtml[$insertLocationStart - 1] -ne '=') {
        $outputHtml += "testResults=$json"
    } else {
        $outputHtml += $json
    }
    $outputHtml += $templateHtml.Substring($insertLocationEnd)

    return $outputHtml
}
