
<#
.SYNOPSIS
    Resets the local cache of Graph API calls. Use this if you need to force a refresh of the cache in the current session.

.DESCRIPTION
    By default all graph responses are cached and re-used for the duration of the session.

    Use this function to clear the cache and force a refresh of the data from Microsoft Graph.
.DESCRIPTION
    By default all graph responses are cached and re-used for the duration of the session.

    Use this function to clear the cache and force a refresh of the data from Microsoft Graph.

.EXAMPLE
    Clear-MtGraphCache

    This example clears the cache of all Graph API calls.

.LINK
    https://maester.dev/docs/commands/Clear-MtGraphCache
#>
function Clear-MtGraphCache {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='Setting module level variable')]
    [CmdletBinding()]
    param()

    Write-Verbose -Message "Clearing the results cached from Graph API calls in this session"

    $__MtSession.GraphCache = @{}
}