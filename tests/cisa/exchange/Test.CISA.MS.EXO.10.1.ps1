function Test-MtCheckCISAMSEXO101 {
    <#
    .SYNOPSIS
    Emails SHALL be scanned for malware.

    .DESCRIPTION
    Runs the shared check Test-MtCisaAttachmentFilter.
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.10.1',
        Title = 'Emails SHALL be scanned for malware.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-malware',
        Area = 'email-protection',
        ResourceType = 'Policy',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566.001', 'T1204.002'),
        Control = 'cisa-scuba:MS.EXO.10.1',
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = 'JeanPhilippeGeorge'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtCisaAttachmentFilter
    if ($null -eq $result) { return $null }
    return $result
}
