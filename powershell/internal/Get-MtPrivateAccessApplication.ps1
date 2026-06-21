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

    $privateAccessTags = @('IsAccessibleViaZTNAClient', 'NetworkAccessQuickAccessApplication')

    Write-Verbose "Getting Global Secure Access Private Access and Quick Access applications by service principal tag."
    $servicePrincipals = Invoke-MtGraphRequest -RelativeUri 'servicePrincipals' -ApiVersion beta -DisableCache:$DisableCache

    return $servicePrincipals | Where-Object {
        $servicePrincipal = $_
        @($privateAccessTags | Where-Object { $servicePrincipal.tags -contains $_ }).Count -gt 0
    }
}
