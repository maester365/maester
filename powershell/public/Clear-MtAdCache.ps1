<#
.SYNOPSIS
    Clears the local AD cache
#>
function Clear-MtAdCache {
    [CmdletBinding()]
    param()
    $__MtSession.AdCache = @{}
}
