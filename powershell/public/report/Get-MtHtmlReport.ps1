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

    The results are embedded gzip-compressed and Base64-encoded, which keeps the file small. Scripts that
    read the results should read the JSON results file rather than the HTML.

    Reports added with Add-MtReportAttachment are embedded in the page, each in its own element, and
    opened from a button. They are left out when RedactUserIdentity is HtmlOnly or AllOutputs, because
    Maester cannot redact another tool's report. JSON attachments, data that a built-in view of the report
    reads, are kept and redacted the way the results are.

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
                        $slim = [ordered]@{
                            System      = $_.System
                            Type        = $_.Type
                            Id          = $_.Id
                            DisplayName = $_.DisplayName
                            PortalLink  = $_.PortalLink
                            Tests       = @($_.Tests)
                            Referenced  = [bool](@($_.Sources) | Where-Object { $_ -in 'GraphObjects', 'Markdown' })
                        }
                        # Only objects that have facts carry the property, so a report without any stays as small as before.
                        $facts = @(Get-ObjectProperty $_ 'Facts' | Where-Object { $_ })
                        if ($facts.Count -gt 0) {
                            $slim.Facts = @($facts | ForEach-Object {
                                    $fact = [ordered]@{ Name = $_.Name; Value = $_.Value; Tone = $_.Tone; Source = $_.Source; AsOf = $_.AsOf }
                                    # Key and Raw let the report's own summaries read a fact without parsing its text.
                                    $key = Get-ObjectProperty $_ 'Key'
                                    if ($key) { $fact.Key = $key; $fact.Raw = $_.Raw }
                                    [PSCustomObject]$fact
                                })
                        }
                        [PSCustomObject]$slim
                    })
            }
            # The report data lists each attachment without its content, which is written into its own element.
            # Under RedactUserIdentity, JSON attachments are redacted like the results and HTML ones are left out.
            if ($null -ne $copy.Attachments) {
                $listed = @(foreach ($attachment in @($copy.Attachments | Where-Object { $_ -and $_.Content })) {
                        if ($RedactUserIdentity -ne 'None') {
                            if ([string](Get-ObjectProperty $attachment 'ContentType') -ne 'application/json') {
                                $redactedAttachments.Value = $true
                                continue
                            }
                            $attachment = & $redactAttachment $attachment
                        }
                        $attachmentContent.Add($attachment)
                        [PSCustomObject](& $copyWithout $attachment 'Content')
                    })
                if ($RedactUserIdentity -ne 'None' -and $listed.Count -eq 0) {
                    $copy.Remove('Attachments')
                } else {
                    $copy.Attachments = $listed
                }
            }
            [PSCustomObject]$copy
        }

        # The user identities to redact, from the map Invoke-Maester built or from the results' AffectedObjects.
        $replacements = @{}
        if ($RedactUserIdentity -ne 'None') {
            if ($PSBoundParameters.ContainsKey('UserIdentityReplacementMap')) {
                $replacements = $UserIdentityReplacementMap
            } else {
                $replacements = Get-MtUserIdentityReplacementMap -MaesterResults $MaesterResults
                $hasInventory = @($MaesterResults) + @($MaesterResults.Tenants) |
                    Where-Object { $_ -and $_.PSObject.Properties.Name -contains 'AffectedObjects' }
                if (-not $hasInventory) {
                    Write-Warning "RedactUserIdentity: the results carry no AffectedObjects. Only supplied redacted result Markdown and identities in the replacement map can be redacted. Generate affected objects with Invoke-Maester -IncludeAffectedObjects."
                }
            }
        }

        # A copy of a JSON attachment with the same replacements as the results: decompressed, redacted, compressed again.
        $redactAttachment = {
            param($Attachment)
            $item = & $copyWithout $Attachment ''
            $compressed = [System.IO.MemoryStream]::new([System.Convert]::FromBase64String([string]$item.Content))
            try {
                $gunzip = [System.IO.Compression.GZipStream]::new($compressed, [System.IO.Compression.CompressionMode]::Decompress)
                $reader = [System.IO.StreamReader]::new($gunzip, [System.Text.Encoding]::UTF8)
                try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
            } finally {
                $compressed.Dispose()
            }
            $text = ConvertTo-MtRedactedReportContent -Content $text -ReplacementMap $replacements -JsonEncoded
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
            $buffer = [System.IO.MemoryStream]::new()
            try {
                $gzip = [System.IO.Compression.GZipStream]::new($buffer, [System.IO.Compression.CompressionLevel]::SmallestSize, $true)
                try { $gzip.Write($bytes, 0, $bytes.Length) } finally { $gzip.Dispose() }
                $item.Content = [System.Convert]::ToBase64String($buffer.ToArray())
            } finally {
                $buffer.Dispose()
            }
            $item.Size = $bytes.Length
            [PSCustomObject]$item
        }

        $attachmentContent = [System.Collections.Generic.List[object]]::new()
        $redactedAttachments = [ref]$false
        $reportResults = & $removeErrorRecord $MaesterResults

        # Check the copy rather than the input so hashtable results are detected too.
        # Use depth 7 for multi-tenant to handle: Tenants > Tests > ResultDetail > nested objects
        $isMultiTenant = $reportResults.PSObject.Properties.Name -contains 'Tenants'
        $depth = if ($isMultiTenant) { 7 } else { 5 }
        if ($isMultiTenant -and $null -ne $reportResults.Tenants) {
            $reportResults.Tenants = @($reportResults.Tenants | ForEach-Object { & $removeErrorRecord $_ })
        }

        if ($redactedAttachments.Value) {
            Write-Warning "RedactUserIdentity: the HTML reports added with Add-MtReportAttachment are left out of the HTML report, because they cannot be redacted."
        }

        $reportResults = ConvertTo-MtRedactedResult -MaesterResults $reportResults -ReplacementMap $replacements -KeepUserIdentity:($RedactUserIdentity -eq 'None')
        Write-Verbose "Generating HTML report."
        $json = $reportResults | ConvertTo-Json -Depth $depth -Compress -WarningAction Ignore

        # The results are written gzip-compressed and Base64-encoded, as attachments are: the guides and
        # results are text that compresses to about a fifth. Base64 text cannot end the script element.
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $buffer = [System.IO.MemoryStream]::new()
        try {
            $gzip = [System.IO.Compression.GZipStream]::new($buffer, [System.IO.Compression.CompressionLevel]::SmallestSize, $true)
            try { $gzip.Write($bytes, 0, $bytes.Length) } finally { $gzip.Dispose() }
            $data = [System.Convert]::ToBase64String($buffer.ToArray())
        } finally {
            $buffer.Dispose()
        }

        $htmlFilePath = Join-Path -Path $PSScriptRoot -ChildPath '../../assets/ReportTemplate.html'
        $templateHtml = Get-Content -Path $htmlFilePath -Raw

        # Replace the template's data element, which holds a placeholder, with the compressed results.
        $dataElement = [regex]::Match($templateHtml, '<script\b[^>]*\bid="maester-report-data"[^>]*>.*?</script>', 'Singleline')
        if (-not $dataElement.Success) {
            throw "The report template has no maester-report-data element: $htmlFilePath"
        }
        $outputHtml = $templateHtml.Substring(0, $dataElement.Index)
        $outputHtml += '<script type="application/octet-stream" id="maester-report-data" data-encoding="gzip+base64">{0}</script>' -f $data
        $outputHtml += $templateHtml.Substring($dataElement.Index + $dataElement.Length)

        # Each attachment is Base64 text, which cannot end the script element. The report reads it by the element's id.
        if ($attachmentContent.Count -gt 0) {
            $elements = foreach ($attachment in $attachmentContent) {
                $id = [string]$attachment.Id -replace '[^A-Za-z0-9_-]', ''
                $content = [string]$attachment.Content -replace '[^A-Za-z0-9+/=]', ''
                '<script type="application/octet-stream" id="maester-attachment-{0}" data-encoding="{1}">{2}</script>' -f $id, 'gzip+base64', $content
            }
            $bodyEnd = $outputHtml.LastIndexOf('</body>', [System.StringComparison]::OrdinalIgnoreCase)
            if ($bodyEnd -lt 0) { $bodyEnd = $outputHtml.Length }
            $outputHtml = $outputHtml.Insert($bodyEnd, ($elements -join "`n") + "`n")
        }

        return $outputHtml
    }
}
