<#
.SYNOPSIS
    Returns the module details from the psd1 fle.

#>
function Get-MtModuleInfo {
    param()



    Write-Debug $moduleInfo | ConvertTo-Json -Depth 5
    return $moduleInfo
}