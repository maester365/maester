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
        Severity = 'High',
        Category = 'CISA',
        Tag = ('MS.EXO', 'MS.EXO.9.3'),
        Service = 'ExchangeOnline',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtCisaAttachmentFileType
    if ($null -eq $result) { return $null }
    return $result
}