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
        Permission = ('ActiveDirectory:Ldap:rIDManager.rIDAvailablePool:ReadProperty'),
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
    $lower = $pool -band 4294967295UL
    if ($upper -eq 0 -or $lower -gt $upper) { throw "Invalid RID Manager pool boundaries: $upper / $lower." }
    $metrics = Format-MtAdSummaryTable -Values ([ordered]@{
        'RID Manager pool upper bound' = $upper
        'Next allocation boundary' = $lower
        'Boundary difference' = $upper - $lower
    })
    Add-MtTestResultDetail -Result "Review RID consumption and allocation. These boundaries are not a measured count of unused DC-local RID pools.`n`n$metrics" -Investigate
}
