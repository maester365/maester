function Test-MtAdAllowedDnsSuffixesCount {
    <#
    .SYNOPSIS
    Assesses the cached Active Directory snapshot without inferring missing data.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    #>
    [MaesterTest(
        Id = 'AD-DOMS-01',
        Title = 'Allowed DNS suffixes count should be retrievable',
        Product = 'ad',
        Feature = 'domain-and-forest',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:domainDNS.name:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Domain')
    if (-not $state.Domain -or $null -eq $state.Domain.AllowedDnsSuffixes) { throw 'Allowed DNS suffix inventory unavailable.' }
    $suffixes = @($state.Domain.AllowedDnsSuffixes)
    Add-MtTestResultDetail -Result "Allowed DNS suffixes (computer DNS namespace identifiers): $($suffixes.Count). Values: $($suffixes -join ', '). This attribute does not grant or deny permission to join a domain." -Investigate
}
