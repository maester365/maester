
<#
.SYNOPSIS
    Resets the local cache of Graph API calls. Use this if you need to force a refresh of the cache in the current session.

.DESCRIPTION
    By default all graph responses are cached and re-used for the duration of the session.

    Use this function to clear the cache and force a refresh of the data from Microsoft Graph.
.DESCRIPTION
    By default all graph responses are cached and re-used for the duration of the session.

    Use this function to clear the cache and force a refresh of the data from Microsoft Graph.
#>
function Clear-MtGraphCache {
    $MtGraphCache = @{}
}