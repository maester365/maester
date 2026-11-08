function Test-MtAdCrlDistributionPointsCount {
    <#
    .SYNOPSIS
    Inventories Active Directory CRL distribution point objects.
    .DESCRIPTION
    Reports object names, distinguished names and whether a CRL value was published; it does not assess reachability or revocation health.
    #>
    [MaesterTest(
        Id = 'AD-CFG-20',
        Title = 'CRL distribution point inventory',
        Product = 'ad',
        Feature = 'certificate-services',
        Area = 'infrastructure',
        ResourceType = 'CertificateAuthority',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:Configuration/*:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Invoke-MtAdConfigurationInventoryReport -Kind CDP
}
