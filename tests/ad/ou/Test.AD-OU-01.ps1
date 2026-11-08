function Test-MtAdOuOverlappingNameCount {
    <#
    .SYNOPSIS
    OU names are unique across the hierarchy.
    .DESCRIPTION
    Uses cached Active Directory state to assess or inventory ou names are unique across the hierarchy.
    #>
    [MaesterTest(
        Id = 'AD-OU-01',
        Title = 'OU names are unique across the hierarchy',
        Product = 'ad',
        Feature = 'organizational-units',
        Area = 'infrastructure',
        ResourceType = 'OrganizationalUnit',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:organizationalUnit:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $ous = @(Get-MtAdOrganizationalUnitOverview -State (Get-MtADDomainState -Categories @('OrganizationalUnits')))
    $duplicates = @($ous | Group-Object Name | Where-Object Count -gt 1)
    $rows = @('| Repeated OU name | Distinguished names |', '| --- | --- |')
    foreach ($group in $duplicates) {
        $dns = (@($group.Group | ForEach-Object { Format-MtAdSiteInventoryValue $_.DistinguishedName }) -join '; ')
        $rows += '| {0} | {1} |' -f (Format-MtAdSiteInventoryValue $group.Name), $dns
    }
    $ok = $duplicates.Count -eq 0
    $summary = if ($ok) { 'Well done. OU names are unique in the organization hierarchy.' } else { 'Review repeated OU names across the hierarchy and rename where appropriate for administrator clarity.' }
    Add-MtTestResultDetail -Result "$summary $($duplicates.Count) repeated name group(s) among $($ous.Count) OUs. Distinguished names remain unique in Active Directory.`n`n$($rows -join "`n")"
    return $ok
}
