<#
 .Synopsis
  Generates a multi-tenant HTML report by injecting merged results into the Maester report template.

 .Description
    Takes a merged MaesterResults object (from Merge-MtMaesterResult) and generates
    a single HTML file with a tenant selector.

    The report template is resolved in this order:
    1. A custom ReportTemplate.html next to this script (for multi-tenant builds)
    2. The template bundled with the installed Maester module (fallback)

    To use the multi-tenant report UI, build the report from the feature/multi-tenant-report
    branch and copy the built ReportTemplate.html into the powershell/ folder of this repo.
#>
function New-MtMultiTenantHtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject] $MaesterResults,

        [Parameter(Mandatory = $true)]
        [string] $OutputFile
    )

    # Validate input structure
    $isMultiTenant = $MaesterResults.PSObject.Properties.Name -contains 'Tenants'
    if (-not $isMultiTenant -and -not ($MaesterResults.PSObject.Properties.Name -contains 'Tests')) {
        throw "MaesterResults object is missing required 'Tests' or 'Tenants' property."
    }

    # Use depth 7 for multi-tenant to handle: Tenants > Tests > ErrorRecord > nested objects
    $depth = if ($isMultiTenant) { 7 } else { 5 }

    Write-Verbose "Generating HTML report (multi-tenant: $isMultiTenant, depth: $depth)"
    $json = $MaesterResults | ConvertTo-Json -Depth $depth -Compress -WarningAction Ignore

    # 1. Check for a custom template in this repo
    $localTemplate = Join-Path -Path $PSScriptRoot -ChildPath 'ReportTemplate.html'

    if (Test-Path $localTemplate) {
        Write-Verbose "Using local multi-tenant template: $localTemplate"
        $htmlFilePath = $localTemplate
    } else {
        # 2. Fallback to the installed Maester module template
        Write-Verbose "Local template not found, falling back to Maester module template"
        $maesterModule = Get-Module -Name Maester -ListAvailable |
            Sort-Object -Property Version -Descending |
            Select-Object -First 1
        if (-not $maesterModule) {
            throw "Maester module not found and no local ReportTemplate.html. Install Maester or provide a template."
        }
        $htmlFilePath = Join-Path -Path $maesterModule.ModuleBase -ChildPath 'assets/ReportTemplate.html'
    }

    if (-not (Test-Path $htmlFilePath)) {
        throw "ReportTemplate.html not found at: $htmlFilePath"
    }

    $templateHtml = Get-Content -Path $htmlFilePath -Raw

    # Find the JSON data region in the template using the EndOfJson sentinel.
    # The minified output format varies by bundler version:
    #   Older: testResults={...EndOfJson:"EndOfJson"}
    #   Newer: var xx={...EndOfJson:`EndOfJson`}
    # We search for the EndOfJson marker (with either quotes or backticks),
    # then scan backwards to find the opening brace of the data object.

    # Find the LAST end marker (the outer wrapper's EndOfJson, not a tenant's)
    # Multi-tenant templates have multiple EndOfJson markers: one per tenant + one for the wrapper
    $endMarkerDoubleQuote = 'EndOfJson:"EndOfJson"}'
    $endMarkerBacktick = 'EndOfJson:`EndOfJson`}'
    $insertLocationEnd = $templateHtml.LastIndexOf($endMarkerDoubleQuote)
    $endMarkerLength = $endMarkerDoubleQuote.Length

    if ($insertLocationEnd -lt 0) {
        $insertLocationEnd = $templateHtml.LastIndexOf($endMarkerBacktick)
        $endMarkerLength = $endMarkerBacktick.Length
    }

    if ($insertLocationEnd -lt 0) {
        throw "Could not find EndOfJson marker in the report template."
    }

    $insertLocationEnd += $endMarkerLength

    # Find the start: look for 'testResults=' or scan back from EndOfJson to find the data object start
    $startMarker = 'testResults='
    $insertLocationStart = $templateHtml.IndexOf($startMarker)

    if ($insertLocationStart -ge 0) {
        # Classic format: testResults={...}
        Write-Verbose "Found classic marker: testResults="
    } else {
        # Newer minified format: var xx={Tenants:... or var xx={Result:...
        # Scan backwards from the EndOfJson position to find the '={' that starts the data object
        # We look for the pattern '={' which is the variable assignment
        $searchRegion = $templateHtml.Substring(0, $insertLocationEnd)
        $dataStartPatterns = @('={Tenants:[', '={Result:', '={Result:`')
        $insertLocationStart = -1

        foreach ($pattern in $dataStartPatterns) {
            $pos = $searchRegion.LastIndexOf($pattern)
            if ($pos -ge 0) {
                # Include the '=' in the replacement so we get 'varname=<our json>'
                $insertLocationStart = $pos + 1  # skip the '=' sign, keep the varname
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
        # Classic format: we matched 'testResults=' so include 'testResults='
        $outputHtml += "testResults=$json"
    } else {
        # Minified format: we're right after the '=', just inject the JSON
        $outputHtml += $json
    }
    $outputHtml += $templateHtml.Substring($insertLocationEnd)

    $outputHtml | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Verbose "Report written to: $OutputFile"
}
