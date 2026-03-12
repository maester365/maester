function Get-MtModuleInfo {
<#
.SYNOPSIS
    Returns the module details from the psd1 file.
#>
    [CmdletBinding()]
    [OutputType([PSObject])]
    param()
    $MtModuleInfo = $MyInvocation.MyCommand.Module
    $MtModuleInfo | ConvertTo-Json -Depth 5 | Write-Debug
    return $MtModuleInfo
}
