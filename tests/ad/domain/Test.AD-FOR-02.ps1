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
    $rows = @('| Forest domain |', '| --- |')
    foreach ($domain in $domains) { $rows += '| {0} |' -f (Format-MtAdSiteInventoryValue $domain) }
    Add-MtTestResultDetail -Result "Review the forest domain topology. The number of domains alone is not a finding.`n`n| Metric | Value |`n| --- | --- |`n| Forest domain count | $($domains.Count) |`n`n$($rows -join "`n")" -Investigate
}
