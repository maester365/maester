function ConvertTo-MtAdConfigurationInventoryCell {
    [CmdletBinding()]
    [OutputType([string])]
    param($Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return '—' }
    return [System.Net.WebUtility]::HtmlEncode(([string]$Value -replace '\r\n|\r|\n', ' ')).Replace('|', '&#124;')
}
