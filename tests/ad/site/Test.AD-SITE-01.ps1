function Test-MtAdSiteTotalCount {
    <#
    .SYNOPSIS
    Site inventory for review.
    .DESCRIPTION
    Uses cached Active Directory state to assess or inventory site inventory for review.
    .EXAMPLE
    Invoke-MtTest -Id AD-SITE-01
    Review the site inventory manually.
    .LINK
    https://maester.dev/docs/tests/AD-SITE-01
    #>
    [MaesterTest(
        Id = 'AD-SITE-01',
        Title = 'Site inventory for review',
        Product = 'ad',
        Feature = 'sites-and-subnets',
        Area = 'infrastructure',
        ResourceType = 'AdSite',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:site:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('ReplicationSites')
    $view = Get-MtAdSiteSubnetOverview -State $state -Sites
    $rows = @('| Site | Type | Parent | Distinguished name |', '| --- | --- | --- | --- |')
    foreach ($site in $view.Sites) {
        $dn = [string]$site.DistinguishedName
        $parent = $dn -replace '^(?:\\.|[^,])+,', ''
        if (-not $site.ObjectClass) { throw "Site '$dn' has missing ObjectClass metadata." }
        $type = @($site.ObjectClass) -join ', '
        $rows += '| {0} | {1} | {2} | {3} |' -f (Format-MtAdSiteInventoryValue $site.Name), (Format-MtAdSiteInventoryValue $type), (Format-MtAdSiteInventoryValue $parent), (Format-MtAdSiteInventoryValue $dn)
    }
    Add-MtTestResultDetail -Result "Review $($view.Sites.Count) replication site(s).`n`n$($rows -join "`n")" -Investigate
    return $true
}
