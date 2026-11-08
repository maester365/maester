function Test-MtAdSiteWithoutSubnetCount {
    <#
    .SYNOPSIS
    Site and subnet association health.
    .DESCRIPTION
    Uses cached Active Directory state to assess or inventory site and subnet association health.
    #>
    [MaesterTest(
        Id = 'AD-SITE-04',
        Title = 'Site and subnet association health',
        Product = 'ad',
        Feature = 'sites-and-subnets',
        Area = 'infrastructure',
        ResourceType = 'AdSite',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:site:ReadProperty', 'ActiveDirectory:Ldap:subnet:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('ReplicationSites', 'Subnets')
    $view = Get-MtAdSiteSubnetOverview -State $state -Sites -Subnets
    $rows = @('| Unassociated site | Distinguished name |', '| --- | --- |')
    foreach ($site in $view.SitesWithoutSubnets) {
        $rows += '| {0} | {1} |' -f (Format-MtAdSiteInventoryValue $site.Name), (Format-MtAdSiteInventoryValue $site.DistinguishedName)
    }
    $rows += '', '| Orphaned subnet (missing or unknown site) | Subnet DN | SiteObject DN |', '| --- | --- | --- |'
    foreach ($subnet in $view.OrphanedSubnets) {
        $rows += '| {0} | {1} | {2} |' -f (Format-MtAdSiteInventoryValue $subnet.Name), (Format-MtAdSiteInventoryValue $subnet.DistinguishedName), (Format-MtAdSiteInventoryValue $subnet.SiteObject)
    }
    $healthy = $view.SitesWithoutSubnets.Count -eq 0 -and $view.OrphanedSubnets.Count -eq 0
    $summary = if ($healthy) { 'Well done. All sites and subnets have valid associations.' } else { 'Review sites without subnets and subnets without a valid site association.' }
    Add-MtTestResultDetail -Result "$summary Sites: $($view.Sites.Count); subnets: $($view.Subnets.Count); sites with subnets: $($view.SitesWithSubnets.Count); sites without subnets: $($view.SitesWithoutSubnets.Count); orphaned subnets: $($view.OrphanedSubnets.Count).`n`n$($rows -join "`n")"
    return $healthy
}
