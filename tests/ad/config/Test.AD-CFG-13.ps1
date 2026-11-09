function Test-MtAdCertificateTemplatesCount {
    <#
    .SYNOPSIS
    Inventories certificate template objects and CA publication references.
    .DESCRIPTION
    Cross-references template CNs with published template names and lists missing references for review without judging security of templates.
    .EXAMPLE
    Invoke-MtTest -Id AD-CFG-13
    Review certificate templates and CA publication references manually.
    .LINK
    https://maester.dev/docs/tests/AD-CFG-13
    #>
    [MaesterTest(
        Id = 'AD-CFG-13',
        Title = 'Certificate template publication inventory',
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

    return Invoke-MtAdConfigurationInventoryReport -Kind Templates
}
