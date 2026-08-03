function Get-MtPrivateAccessApplication {
    <#
    .SYNOPSIS
        Returns the Entra Private Access and Quick Access applications in the tenant.

    .DESCRIPTION
        Global Secure Access Private Access applications cannot be enumerated via the application
        onPremisesPublishing property - that property is absent from the default projection of
        /applications and cannot be selected (Graph returns 400/404). Instead, these apps are
        identified by their service principal tags: 'IsAccessibleViaZTNAClient' (Entra Private
        Access apps) and 'NetworkAccessQuickAccessApplication' (the Quick Access app).

        Returns the matching service principal objects (each exposes appId and id).

    .EXAMPLE
        Get-MtPrivateAccessApplication

        Returns all Entra Private Access and Quick Access service principals.
    #>
    [CmdletBinding()]
    param (
        # Specify if this request should skip cache and go directly to Graph.
        [Parameter(Mandatory = $false)]
        [Switch]$DisableCache
    )

    Write-Verbose "Getting Global Secure Access Private Access and Quick Access applications by service principal tag."
    # Filter server-side by the two known Global Secure Access tags instead of enumerating every service
    # principal in the tenant. tags/any(...) is an advanced query, so $count=true is required (the
    # ConsistencyLevel: eventual header is sent by Invoke-MtGraphRequest by default).
    $filter = "tags/any(t:t eq 'IsAccessibleViaZTNAClient') or tags/any(t:t eq 'NetworkAccessQuickAccessApplication')"
    return Invoke-MtGraphRequest -RelativeUri 'servicePrincipals' -Filter $filter -Select 'id,appId,displayName,tags' -QueryParameters @{ '$count' = 'true' } -ApiVersion beta -DisableCache:$DisableCache
}
