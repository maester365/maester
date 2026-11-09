function Test-MtAdNtAuthCertificatesCount {
    <#
    .SYNOPSIS
    Inventories published NTAuth public certificates.
    .DESCRIPTION
    Reports NTAuth certificate subject, issuer, dates and thumbprint for review; expiry is not a baseline failure.
    .EXAMPLE
    Invoke-MtTest -Id AD-CFG-21
    Review NTAuth certificates manually; expiration is not a failing baseline.
    .LINK
    https://maester.dev/docs/tests/AD-CFG-21
    #>
    [MaesterTest(
        Id = 'AD-CFG-21',
        Title = 'NTAuth certificate inventory',
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

    return Invoke-MtAdConfigurationInventoryReport -Kind NTAuth
}
