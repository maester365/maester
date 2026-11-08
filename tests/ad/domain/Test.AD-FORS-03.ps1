function Test-MtAdSpnSuffixesCount {
    <#
    .SYNOPSIS
    Assesses the cached Active Directory snapshot without inferring missing data.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    #>
    [MaesterTest(
        Id = 'AD-FORS-03',
        Title = 'SPN suffix inventory for review',
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
    if (-not $state.Forest -or $null -eq $state.Forest.SPNSuffixes) { throw 'Forest SPN suffixes not collected.' }
    $suffixes = @($state.Forest.SPNSuffixes)
    Add-MtTestResultDetail -Result "Configured SPN suffix count: $($suffixes.Count); values: $($suffixes -join ', '). Review registered namespaces; this is not a count of SPNs or their owners." -Investigate
}
