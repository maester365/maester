function Test-MtAdAllowedDnsSuffixesCount {
    <#
    .SYNOPSIS
    Assesses the cached Active Directory snapshot without inferring missing data.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    .EXAMPLE
    Invoke-MtTest -Id AD-DOMS-01
    Review the retrieved allowed DNS suffix count manually.
    .LINK
    https://maester.dev/docs/tests/AD-DOMS-01
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
    $rows = @('| Allowed computer DNS suffix |', '| --- |')
    foreach ($suffix in $suffixes) { $rows += '| {0} |' -f (Format-MtAdSiteInventoryValue $suffix) }
    if ($suffixes.Count -eq 0) { $rows += '| None configured |' }
    Add-MtTestResultDetail -Result "Review allowed computer DNS namespace identifiers. This attribute does not grant or deny permission to join a domain.`n`n| Metric | Value |`n| --- | --- |`n| Allowed DNS suffix count | $($suffixes.Count) |`n`n$($rows -join "`n")" -Investigate
}
