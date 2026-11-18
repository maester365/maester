function Format-MtAdSiteInventoryValue {
    [CmdletBinding()]
    [OutputType([string])]
    param($Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return '—' }
    $text = [string]$Value -replace '[\r\n]+', ' '
    return [System.Net.WebUtility]::HtmlEncode($text).Replace('|', '&#124;')
}
