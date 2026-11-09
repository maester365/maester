function Test-MtAdEnrollmentCaCertificateDetails {
    <#
    .SYNOPSIS
    Inventories public certificates in Enterprise CA, trusted root and intermediate CA containers.
    .DESCRIPTION
    Reports public certificate subject, issuer, dates and thumbprint by directory role. Expired certificates are observations for review, not a failing baseline.
    .EXAMPLE
    Invoke-MtTest -Id AD-CFG-15
    Review the published certificate inventory manually.
    .LINK
    https://maester.dev/docs/tests/AD-CFG-15
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Existing public test function name is preserved.')]
    [MaesterTest(
        Id = 'AD-CFG-15',
        Title = 'CA certificate inventory',
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

    return Invoke-MtAdConfigurationInventoryReport -Kind Certificates
}
