function Test-MtAdDcNonGlobalCatalogCount {
    <#
    .SYNOPSIS
    Assesses the cached Active Directory snapshot without inferring missing data.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    #>
    [MaesterTest(
        Id = 'AD-DCD-04',
        Title = 'Forest has at least one Global Catalog',
        Product = 'ad',
        Feature = 'domain-controllers',
        Area = 'infrastructure',
        ResourceType = 'DomainController',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:nTDSDSA:ReadProperty', 'ActiveDirectory:Ldap:crossRef:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('DomainControllers', 'Forest')
    if (-not $state.Forest -or @($state.Forest.Domains).Count -eq 0 -or $null -eq $state.DomainControllers) { throw 'Forest domains or DC inventory unavailable.' }
    $controllers = @($state.DomainControllers)
    if ($controllers.Count -eq 0 -or @($controllers | Where-Object { $null -eq $_.IsGlobalCatalog }).Count -gt 0) { throw 'Incomplete GC status or empty DC inventory.' }
    $catalogs = @($controllers | Where-Object { $_.IsGlobalCatalog -eq $true })
    $nonCatalogs = @($controllers | Where-Object { $_.IsGlobalCatalog -eq $false })
    $ok = $catalogs.Count -gt 0
    Add-MtTestResultDetail -Result "$(if ($ok) { 'Well done. At least one forest Global Catalog is inventoried.' } else { 'Designate and verify at least one forest Global Catalog.' }) GC: $($catalogs.Count); non-GC: $($nonCatalogs.Count). Non-GC DCs are not automatically a failure: the Infrastructure Master placement exception depends on forest topology and Recycle Bin state. This does not prove site reachability."
    return $ok
}
