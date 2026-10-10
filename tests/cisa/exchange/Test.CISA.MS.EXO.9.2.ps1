function Test-MtCheckCISAMSEXO92 {
    <#
    .SYNOPSIS
    The attachment filter SHOULD attempt to determine the true file type and assess the file extension.

    .DESCRIPTION
    Runs the shared check Test-MtCisaAttachmentFileType.
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.9.2',
        Title = 'The attachment filter SHOULD attempt to determine the true file type and assess the file extension.',
        Severity = 'Medium',
        Category = 'CISA',
        Product = 'Exchange Online',
        Tag = ('MS.EXO', 'MS.EXO.9.2'),
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
