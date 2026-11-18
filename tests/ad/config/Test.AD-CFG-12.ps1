function Test-MtAdEnterpriseCaCount {
    <#
    .SYNOPSIS
    Inventories Enterprise CA objects and their published templates.
    .DESCRIPTION
    Reports Enterprise CA names, DNS hosts, and published template names for administrator review; does not assert an expected count.
    .EXAMPLE
    Invoke-MtTest -Id AD-CFG-12
    Review the Enterprise CA and published template inventory manually.
    .LINK
    https://maester.dev/docs/tests/AD-CFG-12
    #>
    [MaesterTest(
        Id = 'AD-CFG-12',
        Title = 'Enterprise CA inventory',
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

    return Invoke-MtAdConfigurationInventoryReport -Kind EnterpriseCAs
}
