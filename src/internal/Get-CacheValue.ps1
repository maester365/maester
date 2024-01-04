<#
.SYNOPSIS
    Reads a value from the cache and returns it.

#>
function Get-CacheValue {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # The unique key for the value to be retrieved.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string] $Key
    )

    if ($MtGraphCache.ContainsKey($key)) {
        return $MtGraphCache[$key]
    } else {
        return $null
    }
}