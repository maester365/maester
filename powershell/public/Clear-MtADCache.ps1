function Clear-MtADCache {
    <#
    .SYNOPSIS
    Resets the local cache of Active Directory data. Use this if you need to force a refresh of the cache in the current session.

    .DESCRIPTION
    By default all Active Directory data is cached and re-used for the duration of the session.

    Use this function to clear the cache and force a refresh of the data from Active Directory.

    .EXAMPLE
    Clear-MtADCache

    This example clears the cache of all Active Directory data.

    .LINK
    https://maester.dev/docs/commands/Clear-MtADCache
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='Setting module level variable')]
    [CmdletBinding()]
    param()

    Write-Verbose -Message "Clearing the results cached from Active Directory in this session"

    $__MtSession.ADCache = @{}
    $__MtSession.ADCollectionTime = $null
}
