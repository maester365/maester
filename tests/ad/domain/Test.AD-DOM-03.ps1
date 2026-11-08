function Test-MtAdDomainControllerCount {
    <#
    .SYNOPSIS
    Assesses the cached Active Directory snapshot without inferring missing data.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    #>
    [MaesterTest(
        Id = 'AD-DOM-03',
        Title = 'Connected domain DC count for review',
        Product = 'ad',
        Feature = 'domain-controllers',
        Area = 'infrastructure',
        ResourceType = 'DomainController',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:domainDNS.name:ReadProperty', 'ActiveDirectory:Ldap:nTDSDSA:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Domain', 'DomainControllers')
    $controllers = @(Get-MtAdDomainControllersInScope -State $state)
    Add-MtTestResultDetail -Result "Connected domain $($state.Domain.DnsRoot) has $($controllers.Count) inventoried DC(s): $($controllers.Name -join ', '). This count does not establish availability or physical redundancy." -Investigate
}
