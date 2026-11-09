function Test-MtAdSiteWithoutDcCount {
    <#
    .SYNOPSIS
    Sites without local domain controllers meet the organization baseline.
    .DESCRIPTION
    Uses cached Active Directory state to assess or inventory sites without local domain controllers meet the organization baseline.
    #>
    [MaesterTest(
        Id = 'AD-SITE-02',
        Title = 'Sites without local domain controllers meet the organization baseline',
        Product = 'ad',
        Feature = 'sites-and-subnets',
        Area = 'infrastructure',
        ResourceType = 'AdSite',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:nTDSDSA:ReadProperty', 'ActiveDirectory:Ldap:site:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Site names intentionally permitted to have no local domain controller.
        [string[]] $AllowedSitesWithoutDcs
    )

    # Sites without a local DC can be intentional; configure their names as exceptions.
    $state = Get-MtADDomainState -Categories @('ReplicationSites', 'DomainControllers')
    $view = Get-MtAdSiteSubnetOverview -State $state -Sites -Controllers
    $missing = @($view.SitesWithoutDcs | Where-Object { $AllowedSitesWithoutDcs -notcontains $_.Name })
    $rows = @('| Site without local DC | Distinguished name |', '| --- | --- |')
    foreach ($site in $view.SitesWithoutDcs) {
        $rows += '| {0} | {1} |' -f (Format-MtAdSiteInventoryValue $site.Name), (Format-MtAdSiteInventoryValue $site.DistinguishedName)
    }
    $summary = if ($missing.Count -eq 0) { 'Well done. All sites without local DCs meet the configured organization baseline.' } else { "$($missing.Count) site(s) without local DCs are not in the allowed list; review coverage or add intentional exceptions." }
    $metrics = Format-MtAdSummaryTable -Values ([ordered]@{
        'Total sites' = $view.Sites.Count
        'Sites with DCs' = $view.Sites.Count - $view.SitesWithoutDcs.Count
        'Sites without DCs' = $view.SitesWithoutDcs.Count
        'Sites without DCs outside the allowed list' = $missing.Count
    })
    Add-MtTestResultDetail -Result "$summary`n`n$metrics`n`n$($rows -join "`n")"
    return ($missing.Count -eq 0)
}
