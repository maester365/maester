function Test-MtAdSubnetCatchAllCount {
    <#
    .SYNOPSIS
    Broad IPv4 subnet inventory.
    .DESCRIPTION
    Uses cached Active Directory state to assess or inventory broad ipv4 subnet inventory.
    #>
    [MaesterTest(
        Id = 'AD-SUB-03',
        Title = 'Broad IPv4 subnet inventory',
        Product = 'ad',
        Feature = 'sites-and-subnets',
        Area = 'infrastructure',
        ResourceType = 'AdSite',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:subnet:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $view = Get-MtAdSubnetInventory -State (Get-MtADDomainState -Categories @('Subnets'))
    # Broad prefixes are for review, not an absolute rule; include actual CIDR.
    $broad = @($view | Where-Object { $_.IsIpv4 -and $_.Prefix -le 16 })
    $rows = @('| Broad IPv4 CIDR | SiteObject DN |', '| --- | --- |')
    foreach ($entry in $broad) { $rows += '| {0} | {1} |' -f (Format-MtAdSiteInventoryValue $entry.Cidr), (Format-MtAdSiteInventoryValue $entry.Subnet.SiteObject) }
    Add-MtTestResultDetail -Result "Review $($broad.Count) IPv4 subnet(s) with /16 or shorter prefixes out of $(@($view | Where-Object IsIpv4).Count) IPv4 subnet(s).`n`n$($rows -join "`n")" -Investigate
    return $true
}
