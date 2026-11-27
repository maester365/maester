function ConvertTo-MtAdConfigurationInventoryCell {
    [CmdletBinding()]
    [OutputType([string])]
    param($Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return '—' }
    $text = [System.Net.WebUtility]::HtmlEncode([string]$Value).Replace('|', '&#124;')
    Get-MtSafeMarkdown -Text $text
}
