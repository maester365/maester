function Test-MtAdUpnSuffixesCount {
    <#
    .SYNOPSIS
    Lists alternate forest UPN suffixes and their count for review.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    #>
    [MaesterTest(
        Id = 'AD-FORS-01',
        Title = 'Alternate UPN suffix inventory for review',
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
    if (-not $state.Forest -or $null -eq $state.Forest.UPNSuffixes) { throw 'Forest UPN suffixes not collected.' }
    $suffixes = @($state.Forest.UPNSuffixes)
    $rows = @('| # | Alternate UPN suffix |', '| --- | --- |')
    for ($i = 0; $i -lt $suffixes.Count; $i++) { $rows += "| $($i + 1) | $($suffixes[$i]) |" }
    Add-MtTestResultDetail -Result "Configured alternate UPN suffix count: $($suffixes.Count).`n`n$($rows -join "`n")`n`nDomain DNS suffixes remain usable independently of this alternate suffix list. This inventory does not show which user UPNs use these suffixes." -Investigate
}
