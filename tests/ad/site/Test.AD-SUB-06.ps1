function Test-MtAdSubnetNonInternalCount {
    <#
    .SYNOPSIS
    IPv4 prefixes outside RFC1918 inventory.
    .DESCRIPTION
    Uses cached Active Directory state to assess or inventory ipv4 prefixes outside rfc1918 inventory.
    #>
    [MaesterTest(
        Id = 'AD-SUB-06',
        Title = 'IPv4 prefixes outside RFC1918 inventory',
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
    $outside = @($view | Where-Object { $_.IsIpv4 -and -not $_.IsRfc1918Subset })
    $rows = @('| IPv4 CIDR not wholly within RFC1918 | SiteObject DN |', '| --- | --- |')
    foreach ($entry in $outside) { $rows += '| {0} | {1} |' -f (Format-MtAdSiteInventoryValue $entry.Cidr), (Format-MtAdSiteInventoryValue $entry.Subnet.SiteObject) }
    Add-MtTestResultDetail -Result "Review $($outside.Count) IPv4 subnet(s) not wholly contained in RFC1918 ranges. Non-RFC1918 does not necessarily mean public or invalid.`n`n$($rows -join "`n")" -Investigate
    return $true
}
