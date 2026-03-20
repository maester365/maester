<#
.SYNOPSIS
    Resets the local cache of SharePoint Online queries. Use this if you need to force a refresh of the cache in the current session.

.DESCRIPTION
    By default all requests are cached and re-used for the duration of the session.

    Use this function to clear the cache and force a refresh of the data.

.EXAMPLE
    Clear-MtSpoCache

    This example clears the cache of all SPO requests.

.LINK
    https://maester.dev/docs/commands/Clear-MtSpoCache
#>
function Clear-MtSpoCache {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='Setting module level variable')]
    [CmdletBinding()]
    param()

    Write-Verbose -Message "Clearing the results for SPO requests in this session"

    $__MtSession.SpoCache = @{}
}
