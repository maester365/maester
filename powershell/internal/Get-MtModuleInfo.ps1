function Get-MtModuleInfo {
<#
.SYNOPSIS
    Returns the module details from the psd1 fle.
#>
    [CmdletBinding()]
    [OutputType([PSObject])]
    param()
    $MtModuleInfo = $MyInvocation.MyCommand.Module
    Write-Debug $MtModuleInfo | ConvertTo-Json -Depth 5
    return $MtModuleInfo
}
