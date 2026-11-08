function Test-MtAdSmtpSiteLinksCount {
    <#
    .SYNOPSIS
    Inventories IP and SMTP site links by their parent transport containers.
    .DESCRIPTION
    Reports all site links and counts per transport for administrator review, without inferring transport from cost or interval.
    #>
    [MaesterTest(
        Id = 'AD-CFG-23',
        Title = 'Site link transport inventory',
        Product = 'ad',
        Feature = 'sites-and-subnets',
        Area = 'infrastructure',
        ResourceType = 'AdSite',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:Configuration/*:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Invoke-MtAdConfigurationInventoryReport -Kind SiteLinks
}
