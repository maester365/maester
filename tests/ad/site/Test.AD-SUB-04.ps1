function Test-MtAdSubnetIpv6Count {
    <#
    .SYNOPSIS
    IPv6 subnet prefix inventory.
    .DESCRIPTION
    Uses cached Active Directory state to assess or inventory ipv6 subnet prefix inventory.
    .EXAMPLE
    Invoke-MtTest -Id AD-SUB-04
    Review IPv6 subnet prefixes manually.
    .LINK
    https://maester.dev/docs/tests/AD-SUB-04
    #>
    [MaesterTest(
        Id = 'AD-SUB-04',
        Title = 'IPv6 subnet prefix inventory',
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
    $ipv6 = @($view | Where-Object { -not $_.IsIpv4 })
    $rows = @('| IPv6 CIDR | Prefix length | SiteObject DN |', '| --- | --- | --- |')
    foreach ($entry in $ipv6) { $rows += '| {0} | {1} | {2} |' -f (Format-MtAdSiteInventoryValue $entry.Cidr), $entry.Prefix, (Format-MtAdSiteInventoryValue $entry.Subnet.SiteObject) }
    Add-MtTestResultDetail -Result "Review $($ipv6.Count) IPv6 subnet(s) out of $($view.Count) subnets.`n`n$($rows -join "`n")" -Investigate
    return $true
}
