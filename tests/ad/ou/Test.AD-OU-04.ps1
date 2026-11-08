function Test-MtAdOuEmptyCount {
    <#
    .SYNOPSIS
    OUs with no selected visible direct children inventory.
    .DESCRIPTION
    Uses cached Active Directory state to assess or inventory ous with no selected visible direct children inventory.
    #>
    [MaesterTest(
        Id = 'AD-OU-04',
        Title = 'OUs with no selected visible direct children inventory',
        Product = 'ad',
        Feature = 'organizational-units',
        Area = 'infrastructure',
        ResourceType = 'OrganizationalUnit',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:computer:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty', 'ActiveDirectory:Ldap:organizationalUnit:ReadProperty', 'ActiveDirectory:Ldap:user:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Computers', 'Groups', 'OrganizationalUnits', 'Users')
    $view = Get-MtAdOrganizationalUnitOverview -State $state -IncludeChildren
    $rows = @('| OU without direct visible users, groups, computers or child OUs | Distinguished name |', '| --- | --- |')
    foreach ($ou in $view.WithoutSelectedDirectChildren) { $rows += '| {0} | {1} |' -f (Format-MtAdSiteInventoryValue $ou.Name), (Format-MtAdSiteInventoryValue $ou.DistinguishedName) }
    Add-MtTestResultDetail -Result "Review $($view.WithoutSelectedDirectChildren.Count) OU(s) without a direct visible user, group, computer or child OU out of $($view.Ous.Count). Other child object classes are not included; this does not prove an OU is empty.`n`n$($rows -join "`n")" -Investigate
    return $true
}
