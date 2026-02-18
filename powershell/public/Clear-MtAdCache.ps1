<#
.SYNOPSIS
    Resets the local cache of AD lookups. Use this if you need to force a refresh of the cache in the current session.

.DESCRIPTION
    By default all AD queries are cached and re-used for the duration of the session.

    Use this function to clear the cache and force a refresh of the data.

.EXAMPLE
    Clear-MtAdCache

    This example clears the cache of all AD queries.

.LINK
    https://maester.dev/docs/commands/Clear-MtAdCache
#>
function Clear-MtAdCache {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='Setting module level variable')]
    [CmdletBinding()]
    param()

    Write-Verbose -Message "Clearing the results cached from DNS lookups in this session"

    $__MtSession.AdCache = @{}
}