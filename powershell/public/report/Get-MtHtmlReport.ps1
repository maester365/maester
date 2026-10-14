function Get-MtHtmlReport {
    <#
    .Synopsis
    Generates a formatted html report using the MaesterResults object created by ConvertTo-MtMaesterResult

    .Description
    The generated html is a single file that provides a visual representation of the test
    results with a summary view and click through of the details.

    Supports both single-tenant results (from ConvertTo-MtMaesterResult) and multi-tenant
    results (from Merge-MtMaesterResult).

    The report omits each test's ErrorRecord, which the report doesn't display. The
    MaesterResults object passed in and the JSON results file keep it.

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
        [psobject] $MaesterResults,

        # Replaces user identities (display names, user principal names and object ids) with stable stable ids.
        # None: keep the values as-is. HtmlOnly / AllOutputs: redact them from this html report.
        [ValidateSet('None', 'HtmlOnly', 'AllOutputs')]
        [string] $RedactUserIdentity = 'None',

        # Replacement map built by Invoke-Maester, which removes the AffectedObjects it was built from.
        [Parameter(DontShow)]
        [hashtable] $UserIdentityReplacementMap
    )

    process {
        # Shallow copy of a results or test object, which may be a PSCustomObject or a hashtable.
        $copyWithout = {
            param($Object, [string] $ExcludeProperty)
            $copy = [ordered]@{}
            if ($Object -is [System.Collections.IDictionary]) {
                foreach ($key in $Object.Keys) {
                    if ($key -ne $ExcludeProperty) { $copy[$key] = $Object[$key] }
                }
            } else {
                foreach ($property in $Object.PSObject.Properties) {
                    if ($property.Name -ne $ExcludeProperty) { $copy[$property.Name] = $property.Value }
                }
            }
            $copy
        }

        # The report doesn't display ErrorRecord, and its stack traces can make up most of the file
        # and include local file paths. Copy the results without it so the caller's object and the
        # JSON output keep the full record.
        $removeErrorRecord = {
            param($Results)
            $copy = & $copyWithout $Results ''
            if ($null -ne $copy.Tests) {
                # Assign directly so a single test or no tests still serializes as an array.
                $copy.Tests = @(foreach ($sourceTest in $copy.Tests) {
                        $test = & $copyWithout $sourceTest 'ErrorRecord'
                        # RelatedObjects only feeds the AffectedObjects built from it, which the report carries.
                        if ($null -ne $test.ResultDetail) {
                            $test.ResultDetail = [PSCustomObject](& $copyWithout $test.ResultDetail 'RelatedObjects')
                        }
                        [PSCustomObject]$test
                    })
            }
            # The Affected objects page only reads these fields, so the report leaves out the rest
            # (UniqueId, UserPrincipalName, AnchorKind and the Sources list). The JSON output and the
            # objects files keep the full records.
            if ($null -ne $copy.AffectedObjects) {
                $copy.AffectedObjects = @($copy.AffectedObjects | ForEach-Object {
                        [PSCustomObject]@{
                            System      = $_.System
                            Type        = $_.Type
                            Id          = $_.Id
                            DisplayName = $_.DisplayName
                            PortalLink  = $_.PortalLink
                            Tests       = @($_.Tests)
                            Referenced  = [bool](@($_.Sources) | Where-Object { $_ -in 'GraphObjects', 'Markdown' })
                        }
                    })
            }
            [PSCustomObject]$copy
        }

        $reportResults = & $removeErrorRecord $MaesterResults

        # Check the copy rather than the input so hashtable results are detected too.
        # Use depth 7 for multi-tenant to handle: Tenants > Tests > ResultDetail > nested objects
        $isMultiTenant = $reportResults.PSObject.Properties.Name -contains 'Tenants'
        $depth = if ($isMultiTenant) { 7 } else { 5 }
        if ($isMultiTenant -and $null -ne $reportResults.Tenants) {
            $reportResults.Tenants = @($reportResults.Tenants | ForEach-Object { & $removeErrorRecord $_ })
        }

        Write-Verbose "Generating HTML report."
        $json = $reportResults | ConvertTo-Json -Depth $depth -Compress -WarningAction Ignore
        # Redact before escaping: escaped & < > would no longer match the replacement values.
        if ($RedactUserIdentity -ne 'None') {
            if ($PSBoundParameters.ContainsKey('UserIdentityReplacementMap')) {
                $replacements = $UserIdentityReplacementMap
            } else {
                $replacements = Get-MtUserIdentityReplacementMap -MaesterResults $MaesterResults
                $hasInventory = @($MaesterResults) + @($MaesterResults.Tenants) |
                    Where-Object { $_ -and $_.PSObject.Properties.Name -contains 'AffectedObjects' }
                if (-not $hasInventory) {
                    Write-Warning "RedactUserIdentity: the results carry no AffectedObjects, so no user identities can be redacted. Generate them with Invoke-Maester -IncludeAffectedObjects."
                }
            }
            $json = ConvertTo-MtRedactedReportContent -Content $json -ReplacementMap $replacements -JsonEncoded
        }

        # Prevent values from terminating the script element while preserving them when JavaScript parses the JSON.
        $json = $json.Replace('&', '\u0026').Replace('<', '\u003c').Replace('>', '\u003e')

        $htmlFilePath = Join-Path -Path $PSScriptRoot -ChildPath '../../assets/ReportTemplate.html'
        $templateHtml = Get-Content -Path $htmlFilePath -Raw

        # Insert the test results json into the template.
        # Locate the EndOfJson sentinel (handles both double-quote and backtick strings
        # produced by different Vite/Rolldown versions) then walk back to the variable
        # assignment that owns the placeholder object so the same variable name is preserved.
        $endPattern = 'EndOfJson:(?:"EndOfJson"|`EndOfJson`)\}'
        $endMatch = [regex]::Match($templateHtml, $endPattern)
        $insertLocationEnd = $endMatch.Index + $endMatch.Length

        # Find the last variable declaration (var/const/let NAME=) before the end marker.
        $startMatches = [regex]::Matches($templateHtml.Substring(0, $endMatch.Index), '(?:var|const|let)\s+\w+\s*=')
        $startMatch = $startMatches[$startMatches.Count - 1]
        $insertLocationStart = $startMatch.Index + $startMatch.Value.Length  # position just after the '='

        $outputHtml = $templateHtml.Substring(0, $insertLocationStart)
        $outputHtml += $json
        $outputHtml += $templateHtml.Substring($insertLocationEnd)

        return $outputHtml
    }
}
