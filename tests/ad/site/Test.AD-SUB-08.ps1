function Test-MtAdSubnetFirstOctetCount {
    <#
    .SYNOPSIS
    Hierarchical IPv4 prefix overview.
    .DESCRIPTION
    Uses cached Active Directory state to assess or inventory hierarchical ipv4 prefix overview.
    #>
    [MaesterTest(
        Id = 'AD-SUB-08',
        Title = 'Hierarchical IPv4 prefix overview',
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
    $ipv4 = @($view | Where-Object IsIpv4)
    $rows = @('| First octet | First two octets | First three octets | Source CIDR |', '| --- | --- | --- | --- |')
    foreach ($entry in $ipv4) {
        $octets = $entry.Address.GetAddressBytes()
        $rows += '| {0} | {1}.{2} | {3}.{4}.{5} | {6} |' -f $octets[0], $octets[0], $octets[1], $octets[0], $octets[1], $octets[2], (Format-MtAdSiteInventoryValue $entry.Cidr)
    }
    Add-MtTestResultDetail -Result "Review $($ipv4.Count) IPv4 subnet entries by address hierarchy (not inferred /8, /16 or /24 network memberships).`n`n$($rows -join "`n")" -Investigate
    return $true
}
