function Test-MtAdDomainNameStandardCompliance {
    <#
    .SYNOPSIS
    Checks forest domain DNS names and lists any invalid names.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    #>
    [MaesterTest(
        Id = 'AD-DOM-05',
        Title = 'Forest domain DNS names have valid syntax',
        Product = 'ad',
        Feature = 'domain-and-forest',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:crossRef:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Forest')
    $findings = @(Get-MtAdDomainNameFindings -Forest $state.Forest -Kind Dns)
    $ok = $findings.Count -eq 0
    $rows = @('| Forest domain DN | DNS root | Syntax |', '| --- | --- | --- |')
    foreach ($partition in @($state.Forest.DomainPartitions)) {
        $invalid = @($findings | Where-Object { $_ -ceq "$($partition.DnsRoot) ($($partition.DistinguishedName))" }).Count -gt 0
        $rows += "| $($partition.DistinguishedName) | $($partition.DnsRoot) | $(if ($invalid) { 'Invalid' } else { 'Valid' }) |"
    }
    Add-MtTestResultDetail -Result "$(if ($ok) { 'Well done. Forest domain DNS names pass syntax validation.' } else { 'Review invalid forest domain DNS names and plan a supported migration.' }) Forest domains: $($state.Forest.DomainPartitions.Count); invalid: $($findings.Count).`n`n$($rows -join "`n")"
    return $ok
}
