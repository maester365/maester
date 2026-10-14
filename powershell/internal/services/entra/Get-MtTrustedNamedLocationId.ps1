function Get-MtTrustedNamedLocationId {
    <#
    .SYNOPSIS
        Returns the IDs of the named locations that are marked as trusted.

    .DESCRIPTION
        Conditional Access policies reference named locations by ID, so a policy that excludes
        a location tells you nothing about whether that location is trusted. This resolves the
        tenant's named locations and returns only the trusted ones, letting a check distinguish
        a genuine trusted-location exclusion from any other exclusion.

        Only IP named locations carry the isTrusted flag. Country named locations have no trust
        concept and are never returned.

        Returns an empty array when the tenant has no trusted named location.

    .EXAMPLE
        Get-MtTrustedNamedLocationId

        Returns the IDs of the trusted named locations in the tenant.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param ()

    $namedLocations = Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/namedLocations' -ApiVersion beta

    return [string[]]@($namedLocations |
            Where-Object { $_.'@odata.type' -match 'ipNamedLocation' -and $_.isTrusted -eq $true } |
            Select-Object -ExpandProperty id)
}
