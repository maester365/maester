function Test-MtCheckCISAMSEXO93 {
    <#
    .SYNOPSIS
    Disallowed file types SHALL be determined and enforced.

    .DESCRIPTION
    Runs the shared check Test-MtCisaAttachmentFileType.
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.9.3',
        Title = 'Disallowed file types SHALL be determined and enforced.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-malware',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1204.002', 'T1566.001'),
        Service = ('ExchangeOnline', 'SecurityCompliance'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtCisaAttachmentFileType
    if ($null -eq $result) { return $null }
    return $result
}
