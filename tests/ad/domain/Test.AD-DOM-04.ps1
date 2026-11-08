function Test-MtAdRidsRemaining {
    <#
    .SYNOPSIS
    Assesses the cached Active Directory snapshot without inferring missing data.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    #>
    [MaesterTest(
        Id = 'AD-DOM-04',
        Title = 'RID Manager available pool boundaries for review',
        Product = 'ad',
        Feature = 'domain-and-forest',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:domainDNS.rIDAvailablePool:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Domain')
    $raw = $state.Domain.RIDAvailablePool
    if ($null -eq $raw) { throw 'RID Manager rIDAvailablePool is unavailable; it is not a domain-root property.' }
    $pool = [uint64]$raw
    $upper = $pool -shr 32
    $lower = $pool -band [uint64]0xFFFFFFFF
    if ($upper -eq 0 -or $lower -gt $upper) { throw "Invalid RID Manager pool boundaries: $upper / $lower." }
    Add-MtTestResultDetail -Result "RID Manager pool upper bound: $upper; next allocation boundary: $lower; difference: $($upper - $lower). Review RID consumption and allocation; this is not a measured count of unused DC-local RID pools." -Investigate
}
