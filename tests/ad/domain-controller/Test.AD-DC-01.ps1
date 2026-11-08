function Test-MtAdDcSiteCoverageCount {
    <#
    .SYNOPSIS
    Assesses the cached Active Directory snapshot without inferring missing data.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    #>
    [MaesterTest(
        Id = 'AD-DC-01',
        Title = 'Site DNs containing DC objects for review',
        Product = 'ad',
        Feature = 'domain-controllers',
        Area = 'infrastructure',
        ResourceType = 'AdSite',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:nTDSDSA:ReadProperty', 'ActiveDirectory:Ldap:site:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('DomainControllers', 'ReplicationSites')
    if ($null -eq $state.DomainControllers -or $null -eq $state.ReplicationSites) { throw 'DC or replication-site inventory unavailable.' }
    $controllers = @($state.DomainControllers)
    $sites = @($state.ReplicationSites)
    $siteDns = @($controllers | Where-Object { $_.SiteDistinguishedName } | Select-Object -ExpandProperty SiteDistinguishedName -Unique)
    $unknown = @($controllers | Where-Object { -not $_.SiteDistinguishedName })
    Add-MtTestResultDetail -Result "Inventory: $($siteDns.Count) site DN(s) with DC objects out of $($sites.Count) site objects; DCs missing site DN: $($unknown.Count). Sites: $($siteDns -join ', '). This is a DC location inventory, not subnet mapping or live connectivity evidence." -Investigate
}
