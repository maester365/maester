function Format-MtAdGpoResult {
    <#
    .SYNOPSIS
    Formats a Group Policy summary, metrics and non-empty detail table.
    .DESCRIPTION
    Uses one report layout for Group Policy checks. Empty detail sets never render
    table headers. Tenant values are HTML-encoded, pipe-escaped, normalized to
    one line, then escaped for Markdown autolinks and syntax.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Summary,

        [System.Collections.IDictionary] $Metrics,

        [object[]] $Details = @(),

        [string[]] $Properties = @(),

        [string[]] $Headers = @()
    )

    $escapeCell = {
        param([AllowNull()][string] $Text)
        Get-MtSafeMarkdown -Text ([System.Net.WebUtility]::HtmlEncode($Text).Replace('|', '&#124;') -replace '[\r\n]+', ' ')
    }

    $result = [System.Text.StringBuilder]::new()
    [void]$result.Append($Summary)
    if ($null -ne $Metrics -and $Metrics.Count -gt 0) {
        [void]$result.Append("`n`n| Metric | Value |`n| --- | --- |`n")
        foreach ($key in $Metrics.Keys) {
            $label = & $escapeCell ([string]$key)
            $value = if ($null -eq $Metrics[$key]) { 'Unknown' } else { [string]$Metrics[$key] }
            $value = & $escapeCell $value
            [void]$result.Append("| $label | $value |`n")
        }
    }

    $rows = @($Details | Where-Object { $null -ne $_ })
    if ($rows.Count -gt 0) {
        if ($Properties.Count -eq 0) { throw 'Detail properties are required for a Group Policy table.' }
        if ($Headers.Count -eq 0) { $Headers = $Properties }
        if ($Headers.Count -ne $Properties.Count) { throw 'Group Policy table headers and properties must have the same count.' }
        $labels = @($Headers | ForEach-Object {
                & $escapeCell $_
            })
        [void]$result.Append("`n`n#### Details`n`n| $($labels -join ' | ') |`n| $((@($Properties | ForEach-Object { '---' })) -join ' | ') |`n")
        foreach ($row in $rows) {
            $cells = foreach ($property in $Properties) {
                $value = if ($null -eq $row.$property) { 'Unknown' } else { [string]$row.$property }
                & $escapeCell $value
            }
            [void]$result.Append("| $($cells -join ' | ') |`n")
        }
    }
    return $result.ToString()
}
