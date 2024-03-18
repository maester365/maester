
<#
.SYNOPSIS
    Resets the local cache of Graph API calls. Use this if you need to force a refresh of the cache in the current session.

#>
function Clear-MtGraphCache {
    $MtGraphCache.Clear()
}