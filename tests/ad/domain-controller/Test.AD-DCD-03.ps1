function Test-MtAdDcReadOnlyCount {
    <#
    .SYNOPSIS
    Assesses the cached Active Directory snapshot without inferring missing data.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    #>
    [MaesterTest(
        Id = 'AD-DCD-03',
        Title = 'Read-only DC inventory for review',
        Product = 'ad',
        Feature = 'domain-controllers',
        Area = 'infrastructure',
        ResourceType = 'DomainController',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:nTDSDSA:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('DomainControllers')
    if ($null -eq $state.DomainControllers) { throw 'DC inventory unavailable.' }
    $controllers = @($state.DomainControllers)
    $readOnly = @($controllers | Where-Object { $_.IsReadOnly -eq $true })
    $unknown = @($controllers | Where-Object { $null -eq $_.IsReadOnly })
    Add-MtTestResultDetail -Result "RODC inventory: $($readOnly.Count) read-only DC(s), $($unknown.Count) unknown. RODCs may be appropriate where physical security is limited; not every branch site requires one." -Investigate
}
