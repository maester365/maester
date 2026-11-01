function ConvertTo-MtRedactedResult {
    <#
    .SYNOPSIS
    Copies results and prepares result Markdown before export.

    .DESCRIPTION
    Handles single-tenant and merged results without changing the caller's objects.
    The optional alternative covers TestResult only. Other fields retain the existing
    best-effort identity replacement behavior.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject] $MaesterResults,
        [hashtable] $ReplacementMap = @{},
        [switch] $KeepUserIdentity
    )

    $copyObject = {
        param($Object)
        $copy = [ordered]@{}
        if ($Object -is [System.Collections.IDictionary]) {
            foreach ($key in $Object.Keys) { $copy[$key] = $Object[$key] }
        } else {
            foreach ($property in $Object.PSObject.Properties) { $copy[$property.Name] = $property.Value }
        }
        $copy
    }
    $prepare = {
        param($Source)
        $copy = & $copyObject $Source
        if ($null -ne $copy.Tests) {
            $copy.Tests = @(foreach ($sourceTest in $copy.Tests) {
                $test = & $copyObject $sourceTest
                if ($null -ne $test.ResultDetail) {
                    $detail = & $copyObject $test.ResultDetail
                    if ($detail.Contains('TestResultRedacted')) {
                        # Imported alternatives are optional; unusable values use generic redaction.
                        if (-not $KeepUserIdentity -and $detail.TestResultRedacted -is [string] -and -not [string]::IsNullOrWhiteSpace($detail.TestResultRedacted)) {
                            $detail.TestResult = $detail.TestResultRedacted
                        }
                        $detail.Remove('TestResultRedacted')
                    }
                    $test.ResultDetail = [pscustomobject]$detail
                }
                [pscustomobject]$test
            })
        }
        if ($null -ne $copy.Tenants) {
            $copy.Tenants = @(foreach ($tenant in $copy.Tenants) { & $prepare $tenant })
        }
        [pscustomobject]$copy
    }
    $prepared = & $prepare $MaesterResults
    if (-not $KeepUserIdentity -and $ReplacementMap.Count -gt 0) {
        # Preserve the existing generic replacement for fields outside scoped result Markdown.
        $depth = if ($prepared.PSObject.Properties['Tenants']) { 7 } else { 5 }
        return $prepared | ConvertTo-Json -Depth $depth -WarningAction SilentlyContinue |
            ConvertTo-MtRedactedReportContent -ReplacementMap $ReplacementMap -JsonEncoded | ConvertFrom-Json
    }
    return $prepared
}
