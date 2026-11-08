function Test-MtAdOuAtDomainRootCount {
    <#
    .SYNOPSIS
    Root-level OU inventory.
    .DESCRIPTION
    Uses cached Active Directory state to assess or inventory root-level ou inventory.
    #>
    [MaesterTest(
        Id = 'AD-OU-02',
        Title = 'Root-level OU inventory',
        Product = 'ad',
        Feature = 'organizational-units',
        Area = 'infrastructure',
        ResourceType = 'OrganizationalUnit',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:domainDNS.distinguishedName:ReadProperty', 'ActiveDirectory:Ldap:organizationalUnit:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Domain', 'OrganizationalUnits')
    $ous = @(Get-MtAdOrganizationalUnitOverview -State $state)
    if ($null -eq $state.Domain -or [string]::IsNullOrWhiteSpace($state.Domain.DistinguishedName)) { throw 'Domain distinguished name is unavailable.' }
    $roots = @($ous | Where-Object { ($_.DistinguishedName -replace '^(?:\\.|[^,])+,', '') -ieq $state.Domain.DistinguishedName })
    $rows = @('| Root OU | Distinguished name |', '| --- | --- |')
    foreach ($ou in $roots) { $rows += '| {0} | {1} |' -f (Format-MtAdSiteInventoryValue $ou.Name), (Format-MtAdSiteInventoryValue $ou.DistinguishedName) }
    Add-MtTestResultDetail -Result "Review $($roots.Count) root-level OU(s) among $($ous.Count) OUs; a root OU is not inherently risky.`n`n$($rows -join "`n")" -Investigate
    return $true
}
