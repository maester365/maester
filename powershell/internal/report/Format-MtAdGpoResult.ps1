function Format-MtAdGpoResult {
    <#
    .SYNOPSIS
    Formats a Group Policy summary, metrics and non-empty detail table.
    .DESCRIPTION
    Uses one report layout for Group Policy checks. Empty detail sets never render
    table headers. Values are HTML-encoded and normalized to one Markdown cell.
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

    $result = $Summary
    if ($null -ne $Metrics -and $Metrics.Count -gt 0) {
        $result += "`n`n| Metric | Value |`n| --- | --- |`n"
        foreach ($key in $Metrics.Keys) {
            $label = [System.Net.WebUtility]::HtmlEncode([string]$key).Replace('|', '&#124;') -replace '[\r\n]+', ' '
            $value = if ($null -eq $Metrics[$key]) { 'Unknown' } else { [string]$Metrics[$key] }
            $value = [System.Net.WebUtility]::HtmlEncode($value).Replace('|', '&#124;') -replace '[\r\n]+', ' '
            $result += "| $label | $value |`n"
        }
    }

    $rows = @($Details | Where-Object { $null -ne $_ })
    if ($rows.Count -gt 0) {
        if ($Properties.Count -eq 0) { throw 'Detail properties are required for a Group Policy table.' }
        if ($Headers.Count -eq 0) { $Headers = $Properties }
        if ($Headers.Count -ne $Properties.Count) { throw 'Group Policy table headers and properties must have the same count.' }
        $labels = @($Headers | ForEach-Object {
                [System.Net.WebUtility]::HtmlEncode($_).Replace('|', '&#124;') -replace '[\r\n]+', ' '
            })
        $result += "`n`n#### Details`n`n| $($labels -join ' | ') |`n| $((@($Properties | ForEach-Object { '---' })) -join ' | ') |`n"
        foreach ($row in $rows) {
            $cells = foreach ($property in $Properties) {
                $value = if ($null -eq $row.$property) { 'Unknown' } else { [string]$row.$property }
                [System.Net.WebUtility]::HtmlEncode($value).Replace('|', '&#124;') -replace '[\r\n]+', ' '
            }
            $result += "| $($cells -join ' | ') |`n"
        }
    }
    return $result
}
