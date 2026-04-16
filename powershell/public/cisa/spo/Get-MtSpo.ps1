function Get-MtSpo {
    <#
    .SYNOPSIS
    Retrieves SharePoint Online tenant settings via PnP with session caching.

    .DESCRIPTION
    Returns the full SPO tenant configuration from Get-PnPTenant.
    Results are cached in $__MtSession.SpoCache for the duration of the session.
    Use -ClearCache to force a fresh retrieval.

    .EXAMPLE
    Get-MtSpo

    Returns the cached (or freshly retrieved) SPO tenant settings.

    .EXAMPLE
    Get-MtSpo -ClearCache

    Clears the cached settings and retrieves fresh data from Get-PnPTenant.

    .LINK
    https://maester.dev/docs/commands/Get-MtSpo
    #>
    [CmdletBinding()]
    param(
        # Clear the cached SPO tenant settings and retrieve fresh data.
        [switch]$ClearCache
    )

    if ($ClearCache) {
        $__MtSession.SpoCache = @{}
        Write-Verbose "SPO cache cleared."
    }

    if ($null -eq $__MtSession.SpoCache.SpoTenant) {
        Write-Verbose "SPO tenant settings not in cache, requesting."
        $response = Get-PnPTenant -ErrorAction Stop
        $__MtSession.SpoCache.SpoTenant = $response
    } else {
        Write-Verbose "SPO tenant settings in cache."
        $response = $__MtSession.SpoCache.SpoTenant
    }

    return $response
}
