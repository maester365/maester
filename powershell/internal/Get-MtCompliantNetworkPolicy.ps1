function Get-MtCompliantNetworkPolicy {
    <#
    .SYNOPSIS
        Returns the enabled Conditional Access policies that enforce the Global Secure Access Compliant Network control.

    .DESCRIPTION
        Locates the compliantNetworkNamedLocation and returns the enabled Conditional Access policies
        that block based on it (the token-replay protection pattern: include All locations, exclude the
        Compliant Network named location, grant block). Returns an empty array when no Compliant Network
        named location exists or no enabled policy enforces it.

    .EXAMPLE
        Get-MtCompliantNetworkPolicy

        Returns the enabled Conditional Access policies that enforce the Compliant Network control.
    #>
    [CmdletBinding()]
    [OutputType([Object[]])]
    param ()

    $namedLocations = Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/namedLocations' -ApiVersion beta
    $compliantNetworkIds = @($namedLocations | Where-Object { $_.'@odata.type' -match 'compliantNetworkNamedLocation' } | Select-Object -ExpandProperty id)

    if (-not $compliantNetworkIds) {
        return @()
    }

    return Get-MtConditionalAccessPolicy | Where-Object {
        $_.state -eq 'enabled' -and
        $_.grantControls.builtInControls -contains 'block' -and
        (
            @($_.conditions.locations.includeLocations | Where-Object { $_ -in $compliantNetworkIds }).Count -gt 0 -or
            @($_.conditions.locations.excludeLocations | Where-Object { $_ -in $compliantNetworkIds }).Count -gt 0
        )
    }
}
