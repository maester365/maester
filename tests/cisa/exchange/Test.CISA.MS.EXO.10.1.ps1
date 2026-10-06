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
        Severity = 'High',
        Category = 'CISA',
        Tag = ('MS.EXO', 'MS.EXO.10.1'),
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
