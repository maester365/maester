function Test-MtAdForestDomainCount {
    <#
    .SYNOPSIS
    Assesses the cached Active Directory snapshot without inferring missing data.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    #>
    [MaesterTest(
        Id = 'AD-FOR-02',
        Title = 'Forest domain inventory for review',
        Product = 'ad',
        Feature = 'domain-and-forest',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:crossRef:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Forest')
    if (-not $state.Forest -or $null -eq $state.Forest.Domains) { throw 'Forest domains not collected.' }
    $domains = @($state.Forest.Domains)
    Add-MtTestResultDetail -Result "Forest domain count: $($domains.Count); domains: $($domains -join ', '). Review the domain topology; the number alone is not a finding." -Investigate
}
