<#
.SYNOPSIS
    Resets the local cache of DNS lookups. Use this if you need to force a refresh of the cache in the current session.

.DESCRIPTION
    By default all DNS responses are cached and re-used for the duration of the session.

    Use this function to clear the cache and force a refresh of the data.

.EXAMPLE
    Clear-MtDnsCache

    This example clears the cache of all DNS lookups.

.LINK
    https://maester.dev/docs/commands/Clear-MtDnsCache
#>
function Clear-MtDnsCache {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='Setting module level variable')]
    [CmdletBinding()]
    param()

    Write-Verbose -Message "Clearing the results cached from DNS lookups in this session"

    $__MtSession.DnsCache = @()
}