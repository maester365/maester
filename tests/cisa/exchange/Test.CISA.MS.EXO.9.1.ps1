function Test-MtCheckCISAMSEXO91 {
    <#
    .SYNOPSIS
    Emails SHALL be filtered by attachment file types.

    .DESCRIPTION
    Runs the shared check Test-MtCisaAttachmentFilter.
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.9.1',
        Title = 'Emails SHALL be filtered by attachment file types.',
        Severity = 'Medium',
        Category = 'CISA',
        Tag = ('MS.EXO', 'MS.EXO.9.1'),
        Service = 'Graph',
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
